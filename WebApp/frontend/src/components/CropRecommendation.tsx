import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Wheat, Sparkles } from "lucide-react";

const CropRecommendation = () => {
  const [formData, setFormData] = useState({
    nitrogen: "",
    phosphorous: "",
    potassium: "",
    temperature: "",
    humidity: "",
    ph: "",
    rainfall: ""
  });

  const [recommendedCrop, setRecommendedCrop] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const handleInputChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setErrorMsg(null);
    setRecommendedCrop(null);

    try {
      const response = await fetch("/predict", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          nitrogen: parseFloat(formData.nitrogen),
          phosphorous: parseFloat(formData.phosphorous),
          potassium: parseFloat(formData.potassium),
          temperature: parseFloat(formData.temperature),
          humidity: parseFloat(formData.humidity),
          ph: parseFloat(formData.ph),
          rainfall: parseFloat(formData.rainfall),
        }),
      });

      const data = await response.json();
      console.log("API response:", data);

      if (response.ok && data.recommended_crop) {
        setRecommendedCrop(data.recommended_crop);
      } else {
        setErrorMsg(data.error || "Prediction failed");
      }
    } catch (err) {
      console.error("Request error:", err);
      setErrorMsg("Server error. Please try again later.");
    } finally {
      setLoading(false);
    }
  };

  const isFormValid = Object.values(formData).every(value => value.trim() !== "");

  return (
    <section className="py-20 px-6 bg-muted/30">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-12">
          <h2 className="text-4xl md:text-5xl font-bold text-foreground mb-6">
            <span className="bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
              Crop Recommendation
            </span>
          </h2>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Enter your soil parameters to get personalized crop recommendations for optimal yield
          </p>
        </div>

        <Card className="border-2 border-border/50 shadow-strong">
          <CardHeader>
            <CardTitle className="text-2xl font-bold text-foreground flex items-center gap-3">
              <Sparkles className="w-7 h-7 text-primary" />
              Soil Analysis Form
            </CardTitle>
            <CardDescription className="text-base">
              Provide your soil and environmental parameters for accurate crop recommendations
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="grid md:grid-cols-2 gap-6">
                <div className="space-y-2">
                  <Label htmlFor="nitrogen">Amount of Azote (Nitrogen)</Label>
                  <Input
                    id="nitrogen"
                    type="number"
                    placeholder="Enter nitrogen level"
                    value={formData.nitrogen}
                    onChange={(e) => handleInputChange("nitrogen", e.target.value)}
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="phosphorous">Amount of Phosphorous</Label>
                  <Input
                    id="phosphorous"
                    type="number"
                    placeholder="Enter phosphorous level"
                    value={formData.phosphorous}
                    onChange={(e) => handleInputChange("phosphorous", e.target.value)}
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="potassium">Amount of Potassium</Label>
                  <Input
                    id="potassium"
                    type="number"
                    placeholder="Enter potassium level"
                    value={formData.potassium}
                    onChange={(e) => handleInputChange("potassium", e.target.value)}
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="temperature">Soil Temperature (°C)</Label>
                  <Input
                    id="temperature"
                    type="number"
                    placeholder="Enter soil temperature"
                    value={formData.temperature}
                    onChange={(e) => handleInputChange("temperature", e.target.value)}
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="humidity">Soil Humidity (%)</Label>
                  <Input
                    id="humidity"
                    type="number"
                    placeholder="Enter soil humidity"
                    value={formData.humidity}
                    onChange={(e) => handleInputChange("humidity", e.target.value)}
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="ph">Soil pH</Label>
                  <Input
                    id="ph"
                    type="number"
                    step="0.1"
                    placeholder="Enter soil pH"
                    value={formData.ph}
                    onChange={(e) => handleInputChange("ph", e.target.value)}
                  />
                </div>

                <div className="space-y-2 md:col-span-2">
                  <Label htmlFor="rainfall">Amount of Rainfall (mm/month)</Label>
                  <Input
                    id="rainfall"
                    type="number"
                    placeholder="Enter rainfall amount"
                    value={formData.rainfall}
                    onChange={(e) => handleInputChange("rainfall", e.target.value)}
                  />
                </div>
              </div>

              <Button
                type="submit"
                variant="agricultural"
                className="w-full"
                disabled={!isFormValid || loading}
              >
                {loading ? "Analyzing..." : "Get Crop Recommendation"}
              </Button>
            </form>

            {(recommendedCrop || errorMsg) && (
              <div className="mt-8 p-6 bg-primary/5 border border-primary/20 rounded-lg">
                <div className="flex items-center gap-4 mb-4">
                  <div className="p-3 bg-primary/10 rounded-lg">
                    <Wheat className="w-8 h-8 text-primary" />
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-foreground">Recommended Crop</h3>
                    <p className="text-muted-foreground">Based on your soil analysis</p>
                  </div>
                </div>
                <div className="bg-background p-4 rounded-lg border">
                  {errorMsg ? (
                    <p className="text-red-500 font-semibold">
                      ⚠ {errorMsg}
                    </p>
                  ) : (
                    <>
                      <h4 className="text-2xl font-bold text-primary mb-2">{recommendedCrop}</h4>
                      <p className="text-muted-foreground">
                        Based on your soil parameters, {recommendedCrop} is the optimal crop choice for your field.
                      </p>
                    </>
                  )}
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </section>
  );
};

export default CropRecommendation;
