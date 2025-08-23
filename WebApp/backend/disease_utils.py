import json, re, io
from typing import Tuple
from PIL import Image
import google.generativeai as genai

# Prompt for Gemini
DISEASE_PROMPT = """
You are an agronomist. Analyze the plant leaf image for disease.
Return ONLY valid JSON (no markdown, no backticks). Use this schema:
{
  "disease": "string",
  "confidence": 0.0,
  "severity": "mild|moderate|severe|none",
  "advice": "string",
  "precautions": "string"
}
If the leaf looks fine, set disease="Healthy", severity="none".
"""

def parse_json_or_fix(s: str) -> dict:
    s = s.strip()
    try:
        return json.loads(s)
    except Exception:
        pass
    m = re.search(r"\{.*\}", s, flags=re.S)
    if m:
        try:
            return json.loads(m.group(0))
        except Exception:
            pass
    return {
        "disease": "Unknown",
        "confidence": 0.0,
        "severity": "none",
        "advice": s[:500],
        "precautions": "Re-run with a clearer, well-lit photo with a single leaf."
    }

def analyze_leaf(image_file, api_key: str, model_id: str = "gemini-1.5-flash") -> dict:
    """
    Given a file-like object (e.g. from Flask upload), analyze disease using Gemini
    """
    # Convert to JPEG bytes
    img = Image.open(image_file.stream)
    buf = io.BytesIO()
    img.convert("RGB").save(buf, format="JPEG", quality=92)
    image_bytes = buf.getvalue()

    # Call Gemini
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel(model_id)
    resp = model.generate_content([
        DISEASE_PROMPT,
        {"mime_type": "image/jpeg", "data": image_bytes}
    ])
    text = getattr(resp, "text", "") or ""
    parsed = parse_json_or_fix(text)

    # Normalize confidence
    try:
        c = float(parsed.get("confidence", 0))
        parsed["confidence"] = min(1.0, max(0.0, round(c, 3)))
    except Exception:
        parsed["confidence"] = 0.0

    return parsed
