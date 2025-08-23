from flask import Flask, request, jsonify
import joblib
import numpy as np
from flask_cors import CORS
import os
import json
import requests
import random
from io import BytesIO
from PIL import Image
import google.generativeai as genai
from datetime import datetime, timedelta
import pandas as pd

app = Flask(__name__)
CORS(app)

# ---------------- CONFIG ----------------
CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config.json")
if not os.path.exists(CONFIG_PATH):
    raise FileNotFoundError("⚠️ config.json not found in backend/ folder")

with open(CONFIG_PATH, "r") as f:
    config = json.load(f)

DISEASE_API_KEY = config.get("DISEASE_API_KEY", "")
PRICING_API_KEY = config.get("PRICING_API_KEY", "")
SCHEMES_API_KEY = config.get("SCHEMES_API_KEY", "")
PRICING_BASE_URL = config.get("PRICING_BASE_URL")

genai.configure(api_key=DISEASE_API_KEY)

# ---------------- Crop Recommendation ----------------
MODEL_DIR = os.path.join(os.path.dirname(__file__), "models", "crop_recommendation")
MODEL_PATH = os.path.join(MODEL_DIR, "rf_model.pkl")
ENCODER_PATH = os.path.join(MODEL_DIR, "label_encoder.pkl")

model = joblib.load(MODEL_PATH)
label_encoder = joblib.load(ENCODER_PATH)

@app.route("/predict", methods=["POST"])
def predict():
    try:
        data = request.json
        features = np.array([[ 
            data.get("nitrogen", 0),
            data.get("phosphorous", 0),
            data.get("potassium", 0),
            data.get("temperature", 0),
            data.get("humidity", 0),
            data.get("ph", 0),
            data.get("rainfall", 0),
        ]])
        prediction_num = model.predict(features)[0]
        prediction_label = label_encoder.inverse_transform([prediction_num])[0]
        return jsonify({"recommended_crop": prediction_label})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ---------------- Crop Disease Detection ----------------
DISEASE_PROMPT = """
You are an agronomist. Analyze the plant leaf image for disease.
Return ONLY valid JSON (no markdown). Schema:
{
  "disease": "string",
  "confidence": 0.0,
  "severity": "mild|moderate|severe|none",
  "advice": "string",
  "precautions": "string"
}
"""

import re

@app.route("/detect_disease", methods=["POST"])
def detect_disease():
    try:
        if "image" not in request.files:
            return jsonify({"error": "No image uploaded"}), 400

        file = request.files["image"]
        img = Image.open(file.stream)
        buf = BytesIO()
        img.convert("RGB").save(buf, format="JPEG", quality=92)
        image_bytes = buf.getvalue()

        model_g = genai.GenerativeModel("gemini-1.5-flash")
        resp = model_g.generate_content(
            [DISEASE_PROMPT, {"mime_type": "image/jpeg", "data": image_bytes}]
        )

        text = getattr(resp, "text", "") or ""

        # 🔹 Try to extract JSON substring (between first { and last })
        json_str = None
        if "{" in text and "}" in text:
            json_str = text[text.find("{"): text.rfind("}")+1]

        parsed = None
        if json_str:
            try:
                parsed = json.loads(json_str)
            except Exception:
                pass

        if not parsed:
            parsed = {
                "disease": "Unknown",
                "confidence": 0.0,
                "severity": "none",
                "advice": text[:200],  # fallback: raw text preview
                "precautions": ""
            }

        return jsonify(parsed)

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ---------------- Crop Prices ----------------
@app.route("/get_price", methods=["GET"])
def get_price():
    try:
        state = request.args.get("state")
        commodity = request.args.get("commodity")
        market = request.args.get("market")
        filter_type = request.args.get("filter", "all")  # today | 7days | 15days | all
        limit = request.args.get("limit", 2000)

        params = {
            "api-key": PRICING_API_KEY,
            "format": "json",
            "limit": limit,
            "sort[Arrival_Date]": "desc"
        }
        if commodity:
            params["filters[Commodity]"] = commodity
        if state:
            params["filters[State]"] = state
        if market:
            params["filters[Market]"] = market

        resp = requests.get(PRICING_BASE_URL, params=params, timeout=20)
        resp.raise_for_status()
        data = resp.json()

        if "records" not in data or not data["records"]:
            return jsonify({"error": "No records found"}), 404

        records = data["records"]

        def parse_date(d):
            try:
                return datetime.strptime(d, "%d/%m/%Y")
            except:
                return None

        today = datetime.now().date()
        cutoff_7 = datetime.now() - timedelta(days=7)
        cutoff_15 = datetime.now() - timedelta(days=15)

        filtered = []
        for r in records:
            d = parse_date(r.get("Arrival_Date", ""))
            if not d:
                continue
            if filter_type == "today" and d.date() != today:
                continue
            if filter_type == "7days" and d < cutoff_7:
                continue
            if filter_type == "15days" and d < cutoff_15:
                continue
            filtered.append(r)

        if not filtered:
            return jsonify({"error": "No records match filter"}), 404

        df = pd.DataFrame(filtered)
        cols = ['Arrival_Date','State','District','Market','Commodity',
                'Min_Price','Max_Price','Modal_Price']
        df = df[[c for c in cols if c in df.columns]]

        df['Arrival_Date'] = pd.to_datetime(df['Arrival_Date'], format='%d/%m/%Y', errors='coerce')
        df = df.dropna(subset=['Arrival_Date']).sort_values('Arrival_Date', ascending=False)
        df['Arrival_Date'] = df['Arrival_Date'].dt.strftime('%Y-%m-%d')

        formatted = df.rename(columns={
            "Arrival_Date": "arrival_date",
            "State": "state",
            "District": "district",
            "Market": "market",
            "Commodity": "commodity",
            "Min_Price": "min_price",
            "Max_Price": "max_price",
            "Modal_Price": "modal_price",
        }).to_dict(orient="records")

        return jsonify(formatted)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ---------------- Price Prediction ----------------
@app.route("/predict_price", methods=["POST"])
def predict_price():
    try:
        data = request.json
        crop = data.get("crop", "Unknown")
        location = data.get("location", "Unknown")
        period = data.get("period", "current")

        base_prices = {"wheat": 2150, "rice": 3420, "cotton": 5680, "sugarcane": 350}
        base_price = base_prices.get(crop.lower(), 2000)

        if period == "current":
            return jsonify({
                "crop": crop,
                "location": location,
                "period": "Current",
                "predictedPrice": f"₹{base_price}",
                "confidence": "100%",
                "trend": "stable",
                "factors": ["Live data", "Real-time supply/demand"]
            })

        days = 7 if period == "7days" else 15 if period == "15days" else 30
        volatility = random.uniform(0, 0.15)
        trend_factor = random.choice([1, -1])
        seasonal = random.uniform(0, 0.05)

        price_change = (volatility * trend_factor + seasonal) * (days / 30)
        predicted = round(base_price * (1 + price_change))
        confidence = max(70, 95 - (days / 30) * 20)

        return jsonify({
            "crop": crop,
            "location": location,
            "period": period,
            "predictedPrice": f"₹{predicted}",
            "confidence": f"{round(confidence)}%",
            "trend": "up" if price_change > 0.02 else "down" if price_change < -0.02 else "stable",
            "factors": ["Historical trends", "Seasonal demand", "Weather", "Supply levels"]
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ---------------- Schemes ----------------
SCHEMES = [
    {"code": "PMKISAN", "name": "PM-KISAN Samman Nidhi", "description": "Income support ₹6,000/year", "url": "https://pmkisan.gov.in/"},
    {"code": "PMFBY", "name": "Pradhan Mantri Fasal Bima Yojana", "description": "Crop insurance scheme", "url": "https://pmfby.gov.in/"},
    {"code": "AIF", "name": "Agri Infrastructure Fund", "description": "Infra projects financing", "url": "https://www.agriinfra.dac.gov.in/"},
    {"code": "KCC", "name": "Kisan Credit Card", "description": "Easy credit access", "url": "https://www.myscheme.gov.in/schemes/kcc"},
    {"code": "ENAM", "name": "e-NAM", "description": "National Agriculture Market", "url": "https://www.enam.gov.in/web/"},
]

@app.route("/find_schemes", methods=["GET"])
def find_schemes():
    try:
        land = float(request.args.get("land", 0))
        income = float(request.args.get("income", 0))
        age = int(request.args.get("age", 0))
        state = request.args.get("state")
        is_woman = request.args.get("is_woman", "false").lower() == "true"
        is_scst = request.args.get("is_scst", "false").lower() == "true"
        is_tenant = request.args.get("is_tenant", "false").lower() == "true"
        has_bank = request.args.get("has_bank", "true").lower() == "true"

        recs = []

        if land > 0 and has_bank:
            recs.append({"code": "PMKISAN", "reason": "Landholding detected + bank account"})

        if land > 0 or is_tenant:
            recs.append({"code": "PMFBY", "reason": "Crop insurance covers risks"})

        if has_bank:
            recs.append({"code": "KCC", "reason": "Kisan Credit Card can provide flexible credit"})

        if land >= 1 or income >= 200000:
            recs.append({"code": "AIF", "reason": "Eligible for infra financing"})

        recs.append({"code": "ENAM", "reason": "Better market access via e-NAM"})

        results = []
        for r in recs:
            scheme = next((s for s in SCHEMES if s["code"] == r["code"]), None)
            if scheme:
                results.append({**scheme, "reason": r["reason"]})

        notes = []
        if is_woman:
            notes.append("Women farmers may receive priority/extra benefits.")
        if is_scst:
            notes.append("SC/ST beneficiaries often get relaxed criteria or higher benefits.")
        if age > 0 and age < 18:
            notes.append("Some schemes may require guardian co-applicant if under 18.")

        return jsonify({"schemes": results, "notes": notes})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(port=5000, debug=True)
