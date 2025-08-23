import os, sys, json, io, argparse, re
from typing import Tuple

# ====== HARD-CODED GEMINI API KEY (override with --key or GEMINI_API_KEY if needed) ======
API_KEY = "AIzaSyAIiMC6ZLZCZXbfwaugtpVfoqvc3APMdtk"

# Optional deps for image handling
try:
    from PIL import Image
except Exception:
    Image = None

JSON_SCHEMA_HINT = """
Return ONLY valid JSON (UTF-8, no markdown, no backticks). Use this schema:
{
  "disease": "string",             // e.g., "Tomato - Early blight" or "Healthy"
  "confidence": 0.0,               // 0..1
  "severity": "mild|moderate|severe|none",
  "advice": "string",              // short farmer-friendly steps for India
  "precautions": "string"          // prevention tips
}
"""

PROMPT = (
    "You are an agronomist. Analyze the plant leaf image for disease.\n"
    "Identify the most likely disease, confidence, and severity.\n"
    "Give short, practical advice for a small farmer in India and key precautions.\n"
    + JSON_SCHEMA_HINT +
    "\nIf the leaf looks fine, set disease='Healthy', severity='none', confidence appropriately."
)

def die(msg: str, code: int = 1):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)

def ensure_deps():
    try:
        import google.generativeai as genai  # noqa
    except ImportError:
        die(
            "google-generativeai not installed.\n"
            "Install with:\n  python -m pip install --upgrade google-generativeai"
        )
    if Image is None:
        die("Pillow not installed. Install with:\n  python -m pip install pillow")

def load_image_as_jpeg_bytes(path: str) -> bytes:
    if not os.path.exists(path):
        die(f"Image not found: {path}")
    with Image.open(path) as im:
        if im.mode not in ("RGB", "L"):
            im = im.convert("RGB")
        buf = io.BytesIO()
        im.save(buf, format="JPEG", quality=92)
        return buf.getvalue()

def parse_json_or_fix(s: str) -> dict:
    s = s.strip()
    # Direct parse first
    try:
        return json.loads(s)
    except Exception:
        pass
    # If model wrapped JSON in text, try to extract the first JSON object
    m = re.search(r"\{.*\}", s, flags=re.S)
    if m:
        candidate = m.group(0)
        try:
            return json.loads(candidate)
        except Exception:
            pass
    # Last resort: build a minimal object
    return {
        "disease": "Unknown",
        "confidence": 0.0,
        "severity": "none",
        "advice": s[:500],
        "precautions": "Re-run with a clearer, well-lit image; ensure single leaf in frame."
    }

def call_gemini(image_bytes: bytes, api_key: str, model_id: str) -> Tuple[bool, str]:
    import google.generativeai as genai
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel(model_id)
    try:
        resp = model.generate_content([
            PROMPT,
            {"mime_type": "image/jpeg", "data": image_bytes}
        ])
        text = getattr(resp, "text", "") or ""
        return True, text
    except Exception as e:
        return False, str(e)

def main():
    ap = argparse.ArgumentParser(description="Leaf disease detection with Gemini (returns strict JSON).")
    ap.add_argument("--image", "-i", required=True, help="Path to leaf image (JPEG/PNG).")
    ap.add_argument("--key", help="Gemini API key (overrides hardcoded key or env).")
    ap.add_argument("--model", default="gemini-1.5-flash", help="Model ID (default: gemini-1.5-flash).")
    args = ap.parse_args()

    ensure_deps()

    # Resolve API key: CLI > ENV > hardcoded
    api_key = args.key or os.environ.get("GEMINI_API_KEY") or API_KEY
    if not api_key or not api_key.startswith("AIza"):
        die("No valid API key. Pass --key, set GEMINI_API_KEY, or update API_KEY constant.")

    img_bytes = load_image_as_jpeg_bytes(args.image)
    ok, out = call_gemini(img_bytes, api_key, args.model)
    if not ok:
        die(f"Gemini call failed: {out}")

    data = parse_json_or_fix(out)

    # Normalize fields a bit
    data.setdefault("disease", "Unknown")
    data.setdefault("confidence", 0.0)
    data.setdefault("severity", "none")
    data.setdefault("advice", "")
    data.setdefault("precautions", "")

    # Clamp confidence to 0..1 if needed
    try:
        c = float(data["confidence"])
        if c < 0: c = 0.0
        if c > 1: c = 1.0
        data["confidence"] = round(c, 3)
    except Exception:
        data["confidence"] = 0.0

    print(json.dumps(data, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
    
    
    
