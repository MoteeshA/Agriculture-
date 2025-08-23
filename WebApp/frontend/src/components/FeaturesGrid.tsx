import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { TrendingUp, Tractor, Leaf, FileText, Sparkles } from "lucide-react";
import { useNavigate } from "react-router-dom";

const features = [
  {
    icon: Sparkles,
    title: "Crop Recommendation",
    description: "Get personalized crop recommendations based on your soil parameters and environmental conditions using AI-powered analysis.",
    action: "Get Recommendations",
    gradient: "from-primary to-accent",
    path: "/crop-recommendation",
  },
  {
    icon: TrendingUp,
    title: "Crop Price Prediction",
    description: "Get accurate market price forecasts across regions using AI-powered analysis of historical data, weather patterns, and demand trends.",
    action: "Check Prices",
    gradient: "from-accent to-primary",
    path: "/crop-prices",
  },
  {
    icon: Tractor,
    title: "Equipment Rental",
    description: "Find and rent tractors, harvesters, drones, and other farming equipment from fellow farmers in your area.",
    action: "Browse Equipment",
    gradient: "from-primary to-accent",
    path: "/equipment",
  },
  {
    icon: Leaf,
    title: "Crop Health Analysis",
    description: "Upload crop photos for instant AI-powered disease detection, yield predictions, and personalized treatment recommendations.",
    action: "Analyze Crops",
    gradient: "from-accent/80 to-primary/80",
    path: "/crop-health",
  },
  {
    icon: FileText,
    title: "Government Schemes",
    description: "Discover personalized government scheme recommendations based on your profile, crops, and location with easy eligibility checking.",
    action: "Find Schemes",
    gradient: "from-primary/80 to-accent/90",
    path: "/schemes",
  },
];

const FeaturesGrid = () => {
  const navigate = useNavigate();

  return (
    <section className="py-20 px-6 bg-background">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold text-foreground mb-6">
            Everything You Need for
            <span className="block bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
              Smart Farming
            </span>
          </h2>
          <p className="text-xl text-muted-foreground max-w-3xl mx-auto">
            Our comprehensive platform empowers farmers with cutting-edge technology and data-driven insights for better decision making.
          </p>
        </div>
        
        <div className="grid md:grid-cols-2 gap-8">
          {features.map((feature, index) => (
            <Card 
              key={index} 
              className="relative overflow-hidden border-2 border-border/50 hover:border-primary/30 transition-all duration-300 hover:shadow-strong group"
            >
              <div className={`absolute inset-0 bg-gradient-to-br ${feature.gradient} opacity-5 group-hover:opacity-10 transition-opacity duration-300`} />
              <CardHeader className="relative">
                <div className="flex items-start gap-4">
                  <div className="p-3 rounded-lg bg-primary/10 group-hover:bg-primary/20 transition-colors">
                    <feature.icon className="w-8 h-8 text-primary" />
                  </div>
                  <div className="flex-1">
                    <CardTitle className="text-2xl font-bold text-foreground mb-2">
                      {feature.title}
                    </CardTitle>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="relative">
                <CardDescription className="text-base text-muted-foreground mb-6 leading-relaxed">
                  {feature.description}
                </CardDescription>
                <Button 
                  variant="agricultural" 
                  className="w-full"
                  onClick={() => navigate(feature.path)}
                >
                  {feature.action}
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
};

export default FeaturesGrid;