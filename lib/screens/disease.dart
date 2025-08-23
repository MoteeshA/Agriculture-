// lib/screens/disease.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;

/// HARD-CODED GEMINI API KEY (replace if you want)
const String kGeminiApiKey = "AIzaSyAIiMC6ZLZCZXbfwaugtpVfoqvc3APMdtk";

/// Model to use
const String kGeminiModel = "gemini-1.5-flash";

/// JSON-only schema hint + instructions
const String _jsonSchemaHint = '''
Return ONLY valid JSON (UTF-8, no markdown, no backticks). Use this schema:
{
  "is_leaf": true,                // true if the image contains a plant leaf
  "disease": "string",            // e.g., "Tomato - Early blight" or "Healthy" or "Not a leaf"
  "confidence": 0.0,              // 0..1
  "severity": "mild|moderate|severe|none",
  "advice": "string",             // short farmer-friendly steps for India
  "precautions": "string"         // prevention tips
}
''';

const String _prompt = '''
You are an agronomist. Analyze the plant leaf image for disease.

1) First, determine if a plant LEAF is clearly present (is_leaf=true/false).
2) If not a leaf, set is_leaf=false and disease="Not a leaf", severity="none", confidence based on your certainty that it's not a leaf.
3) If it is a leaf, identify the most likely disease (or "Healthy" if fine), give a confidence (0..1), and a severity (mild|moderate|severe|none).
4) Provide short, practical advice for a small farmer in India and key precautions.
5) VERY IMPORTANT: Respond with JSON ONLY, matching the schema exactly. No extra text.

''' + _jsonSchemaHint + '''
If the leaf looks fine, set disease="Healthy" and severity="none".
''';

class DiseasePage extends StatefulWidget {
  static const route = '/disease';
  const DiseasePage({super.key});

  @override
  State<DiseasePage> createState() => _DiseasePageState();
}

class _DiseasePageState extends State<DiseasePage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  Uint8List? _imageBytes;

  bool _loading = false;
  String? _error;

  Map<String, dynamic>? _result; // parsed JSON result

  // --- Pickers ---
  Future<void> _pickFromGallery() async {
    setState(() {
      _error = null;
      _result = null;
    });
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _imageFile = file;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    setState(() {
      _error = null;
      _result = null;
    });
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 92);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _imageFile = file;
        _imageBytes = bytes;
      });
    }
  }

  // --- Gemini call ---
  Future<void> _analyze() async {
    if (_imageBytes == null) {
      setState(() => _error = "Please pick or take a photo first.");
      return;
    }
    if (kGeminiApiKey.isEmpty || !kGeminiApiKey.startsWith("AIza")) {
      setState(() => _error = "Invalid Gemini API key. Update kGeminiApiKey.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final model = genai.GenerativeModel(
        model: kGeminiModel,
        apiKey: kGeminiApiKey,
      );

      final parts = <genai.Part>[
        genai.TextPart(_prompt),
        // Try sending as JPEG; image_picker quality=92 gives JPEG most of the time
        genai.DataPart('image/jpeg', _imageBytes!),
      ];

      final response = await model.generateContent([
        genai.Content.multi(parts),
      ]);

      final text = response.text ?? "";
      final parsed = _parseJsonOrFix(text);

      // Normalize + defaults
      final normalized = <String, dynamic>{
        "is_leaf": parsed["is_leaf"] is bool ? parsed["is_leaf"] : true,
        "disease": (parsed["disease"] ?? "Unknown").toString(),
        "confidence": _clamp01(parsed["confidence"]),
        "severity": (parsed["severity"] ?? "none").toString(),
        "advice": (parsed["advice"] ?? "").toString(),
        "precautions": (parsed["precautions"] ?? "").toString(),
      };

      // If not a leaf, force fields:
      if (normalized["is_leaf"] == false) {
        normalized["disease"] = "Not a leaf";
        normalized["severity"] = "none";
      }

      setState(() {
        _result = normalized;
      });
    } catch (e) {
      setState(() {
        _error = "Gemini call failed: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // --- Helpers ---
  Map<String, dynamic> _parseJsonOrFix(String s) {
    final trimmed = s.trim();
    // Direct parse
    try {
      final obj = json.decode(trimmed);
      if (obj is Map<String, dynamic>) return obj;
    } catch (_) {}

    // Extract first {...} block
    final reg = RegExp(r'\{.*\}', dotAll: true);
    final m = reg.firstMatch(trimmed);
    if (m != null) {
      final candidate = m.group(0)!;
      try {
        final obj = json.decode(candidate);
        if (obj is Map<String, dynamic>) return obj;
      } catch (_) {}
    }

    // Fallback minimal object
    return {
      "is_leaf": true,
      "disease": "Unknown",
      "confidence": 0.0,
      "severity": "none",
      "advice": trimmed.length > 500 ? trimmed.substring(0, 500) : trimmed,
      "precautions": "Re-take a clear, well-lit photo with a single leaf in frame.",
    };
  }

  double _clamp01(dynamic v) {
    try {
      final c = (v is num) ? v.toDouble() : double.parse(v.toString());
      if (c.isNaN) return 0.0;
      if (c < 0) return 0.0;
      if (c > 1) return 1.0;
      return double.parse(c.toStringAsFixed(3));
    } catch (_) {
      return 0.0;
    }
  }

  void _reset() {
    setState(() {
      _imageFile = null;
      _imageBytes = null;
      _result = null;
      _error = null;
      _loading = false;
    });
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaf Disease Detector'),
        backgroundColor: color.primaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Image preview
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
            )
          else
            _placeholderCard(),

          const SizedBox(height: 12),

          // Buttons row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _loading ? null : _pickFromCamera,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Take Photo'),
              ),
              ElevatedButton.icon(
                onPressed: _loading ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Pick from Gallery'),
              ),
              if (_imageBytes != null)
                ElevatedButton.icon(
                  onPressed: _loading ? null : _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                ),
              FilledButton.icon(
                onPressed: (_imageBytes == null || _loading) ? null : _analyze,
                icon: _loading
                    ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.science),
                label: Text(_loading ? 'Analyzing…' : 'Analyze'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_error != null) _errorCard(_error!),

          if (_result != null) _resultCard(_result!),
        ],
      ),
    );
  }

  Widget _placeholderCard() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: Text(
          'Take or pick a photo of a single leaf.\nGood lighting, plain background.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          msg,
          style: TextStyle(color: Colors.red.shade700),
        ),
      ),
    );
  }

  Widget _chip(String label, {Color? bg, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: fg ?? Colors.black)),
    );
  }

  Widget _resultCard(Map<String, dynamic> r) {
    final bool isLeaf = (r["is_leaf"] == true);
    final String disease = r["disease"]?.toString() ?? "Unknown";
    final double conf = _clamp01(r["confidence"]);
    final String severity = r["severity"]?.toString() ?? "none";
    final String advice = r["advice"]?.toString() ?? "";
    final String precautions = r["precautions"]?.toString() ?? "";

    Color sevColor;
    switch (severity.toLowerCase()) {
      case "severe":
        sevColor = Colors.red.shade400;
        break;
      case "moderate":
        sevColor = Colors.orange.shade400;
        break;
      case "mild":
        sevColor = Colors.amber.shade600;
        break;
      default:
        sevColor = Colors.green.shade500;
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLeaf ? "Result" : "Not a leaf",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            if (!isLeaf)
              const Text(
                "Please upload a clear photo of a plant leaf.",
                style: TextStyle(fontSize: 14),
              ),

            if (isLeaf) ...[
              Row(
                children: [
                  _chip("Disease: $disease"),
                  const SizedBox(width: 8),
                  _chip("Confidence: ${(conf * 100).toStringAsFixed(1)}%"),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _chip("Severity: $severity".toUpperCase(), bg: sevColor.withOpacity(0.15), fg: sevColor),
                ],
              ),
              const SizedBox(height: 12),
              if (advice.isNotEmpty) ...[
                const Text("Advice", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(advice),
                const SizedBox(height: 10),
              ],
              if (precautions.isNotEmpty) ...[
                const Text("Precautions", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(precautions),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
