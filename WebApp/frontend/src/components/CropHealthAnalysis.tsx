import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Upload, Camera, Leaf } from "lucide-react";
import { useState } from "react";

interface DiseaseResult {
  disease: string;
  confidence: number;
  severity: string;
  advice: string;
  precautions: string;
}

const CropHealthAnalysis = () => {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<DiseaseResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleImageUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      setSelectedFile(file);
      setPreview(URL.createObjectURL(file));
      setResult(null);
      setError(null);
    }
  };

  const analyzeImage = async () => {
    if (!selectedFile) return;
    setLoading(true);
    setError(null);
    setResult(null);

    const formData = new FormData();
    formData.append("image", selectedFile);

    try {
      const res = await fetch("/detect_disease", {
        method: "POST",
        body: formData,
      });
      const data = await res.json();

      if (data.error) {
        setError(data.error);
      } else {
        setResult(data);
      }
    } catch (err) {
      setError("Failed to analyze image. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <section className="py-20 px-6 bg-muted/30">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold text-foreground mb-6">
            AI-Powered
            <span className="block bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
              Crop Analysis
            </span>
          </h2>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Upload crop images to get instant disease detection and farmer-friendly advice
          </p>
        </div>

        <div className="grid lg:grid-cols-2 gap-12 items-start">
          {/* Upload Section */}
          <Card className="border-2 border-primary/20 shadow-medium">
            <CardHeader className="bg-gradient-to-r from-primary/5 to-accent/5">
              <CardTitle className="text-2xl font-bold text-foreground flex items-center gap-3">
                <Camera className="w-6 h-6 text-primary" />
                Upload Crop Image
              </CardTitle>
              <CardDescription>
                Take a clear photo of your crop leaves or upload from your device
              </CardDescription>
            </CardHeader>
            <CardContent className="p-6">
              <div className="space-y-6">
                {/* Upload Area */}
                <div className="border-2 border-dashed border-border rounded-lg p-8 text-center hover:border-primary/50 transition-colors relative">
                  {preview ? (
                    <div className="space-y-4">
                      <img
                        src={preview}
                        alt="Uploaded crop"
                        className="mx-auto max-w-full h-48 object-cover rounded-lg"
                      />
                      <p className="text-sm text-muted-foreground">Image uploaded successfully</p>
                    </div>
                  ) : (
                    <div className="space-y-4">
                      <Upload className="w-12 h-12 text-muted-foreground mx-auto" />
                      <div>
                        <p className="text-foreground font-medium">
                          Drop your image here or click to upload
                        </p>
                        <p className="text-sm text-muted-foreground mt-2">
                          Supports JPG, PNG files up to 10MB
                        </p>
                      </div>
                    </div>
                  )}
                  {/* input only covers the box */}
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleImageUpload}
                    className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                  />
                </div>

                <Button
                  variant="agricultural"
                  className="w-full"
                  disabled={!selectedFile || loading}
                  onClick={analyzeImage}
                >
                  {loading ? "Analyzing…" : "Analyze Crop Health"}
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Analysis Results */}
          <div className="space-y-6">
            <h3 className="text-2xl font-bold text-foreground mb-6">
              Health Analysis Results
            </h3>

            {error && (
              <Card className="border-l-4 border-l-destructive">
                <CardContent className="p-4 text-destructive">{error}</CardContent>
              </Card>
            )}

            {loading && (
              <Card className="border border-border">
                <CardContent className="p-6 text-center">
                  <p className="text-primary font-medium">Analyzing image… please wait</p>
                </CardContent>
              </Card>
            )}

            {result && (
              <div className="space-y-4">
                {/* Disease */}
                <Card className="border-l-4 border-l-accent">
                  <CardContent className="p-4">
                    <h4 className="font-semibold text-foreground">
                      Disease: {result.disease}
                    </h4>
                    <p className="text-sm text-muted-foreground mt-1">
                      Confidence: {(result.confidence * 100).toFixed(1)}% | Severity: {result.severity}
                    </p>
                  </CardContent>
                </Card>

                {/* Advice */}
                <Card className="border border-border">
                  <CardContent className="p-4">
                    <h4 className="font-semibold text-foreground mb-2">Advice</h4>
                    <p className="text-sm">{result.advice}</p>
                  </CardContent>
                </Card>

                {/* Precautions */}
                <Card className="border border-border">
                  <CardContent className="p-4">
                    <h4 className="font-semibold text-foreground mb-2">Precautions</h4>
                    <p className="text-sm">{result.precautions}</p>
                  </CardContent>
                </Card>
              </div>
            )}

            {!preview && !loading && !error && !result && (
              <Card className="border border-border/50">
                <CardContent className="p-8 text-center">
                  <Leaf className="w-12 h-12 text-muted-foreground mx-auto mb-4" />
                  <p className="text-muted-foreground">
                    Upload a crop image to see AI-powered analysis results
                  </p>
                </CardContent>
              </Card>
            )}
          </div>
        </div>
      </div>
    </section>
  );
};

export default CropHealthAnalysis;
