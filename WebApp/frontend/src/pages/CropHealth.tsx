import CropHealthAnalysis from "@/components/CropHealthAnalysis";
import { Button } from "@/components/ui/button";
import { ArrowLeft, Leaf } from "lucide-react";
import { useNavigate } from "react-router-dom";

const CropHealth = () => {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border/50 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <Button 
                variant="outline" 
                size="sm" 
                onClick={() => navigate("/")}
                className="flex items-center gap-2"
              >
                <ArrowLeft className="w-4 h-4" />
                Back to Home
              </Button>
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-primary/10">
                  <Leaf className="w-6 h-6 text-primary" />
                </div>
                <div>
                  <h1 className="text-2xl font-bold text-foreground">Crop Health Analysis</h1>
                  <p className="text-sm text-muted-foreground">AI-powered crop disease detection</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main>
        <CropHealthAnalysis />
      </main>
    </div>
  );
};

export default CropHealth;