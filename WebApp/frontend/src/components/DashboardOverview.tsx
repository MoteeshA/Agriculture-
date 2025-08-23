import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { TrendingUp, Users, Sprout, Shield, ArrowRight, Calendar } from "lucide-react";
import { useNavigate } from "react-router-dom";

const statsData = [
  { label: "Active Farmers", value: "15,000+", icon: Users, change: "+12%" },
  { label: "Crops Monitored", value: "50,000+", icon: Sprout, change: "+8%" },
  { label: "Price Predictions", value: "95%", icon: TrendingUp, change: "+3%" },
  { label: "Equipment Available", value: "2,500+", icon: Shield, change: "+15%" },
];

const recentActivity = [
  { action: "Price alert for Wheat in Punjab", time: "2 hours ago", type: "price" },
  { action: "New tractor available in your area", time: "4 hours ago", type: "equipment" },
  { action: "Crop health report completed", time: "1 day ago", type: "health" },
  { action: "New government scheme available", time: "2 days ago", type: "scheme" },
];

const quickActions = [
  { title: "Check Today's Prices", description: "Get latest mandi rates", path: "/crop-prices", icon: TrendingUp },
  { title: "Rent Equipment", description: "Find nearby tools", path: "/equipment", icon: Shield },
  { title: "Health Checkup", description: "Analyze crop photos", path: "/crop-health", icon: Sprout },
  { title: "Browse Schemes", description: "Discover benefits", path: "/schemes", icon: Calendar },
];

const DashboardOverview = () => {
  const navigate = useNavigate();

  return (
    <section className="py-12 px-6 bg-background">
      <div className="max-w-7xl mx-auto">
        {/* Welcome Section */}
        <div className="mb-12">
          <h2 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            Welcome to Your
            <span className="block bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
              Farming Dashboard
            </span>
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl">
            Monitor your crops, track market trends, and make informed decisions with real-time data and AI insights.
          </p>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-6 mb-12">
          {statsData.map((stat, index) => (
            <Card key={index} className="border border-border/50 hover:border-primary/30 transition-colors">
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-muted-foreground mb-1">{stat.label}</p>
                    <p className="text-2xl font-bold text-foreground">{stat.value}</p>
                    <p className="text-sm text-green-600 font-medium">{stat.change}</p>
                  </div>
                  <div className="p-3 rounded-lg bg-primary/10">
                    <stat.icon className="w-6 h-6 text-primary" />
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        <div className="grid lg:grid-cols-3 gap-8">
          {/* Quick Actions */}
          <div className="lg:col-span-2">
            <Card className="border-2 border-primary/20">
              <CardHeader>
                <CardTitle className="text-xl font-bold text-foreground">Quick Actions</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid sm:grid-cols-2 gap-4">
                  {quickActions.map((action, index) => (
                    <Card 
                      key={index} 
                      className="border border-border/50 hover:border-primary/30 transition-all duration-200 hover:shadow-md cursor-pointer group"
                      onClick={() => navigate(action.path)}
                    >
                      <CardContent className="p-4">
                        <div className="flex items-center gap-3">
                          <div className="p-2 rounded-lg bg-primary/10 group-hover:bg-primary/20 transition-colors">
                            <action.icon className="w-5 h-5 text-primary" />
                          </div>
                          <div className="flex-1">
                            <h4 className="font-semibold text-foreground group-hover:text-primary transition-colors">
                              {action.title}
                            </h4>
                            <p className="text-sm text-muted-foreground">{action.description}</p>
                          </div>
                          <ArrowRight className="w-4 h-4 text-muted-foreground group-hover:text-primary transition-colors" />
                        </div>
                      </CardContent>
                    </Card>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Recent Activity */}
          <Card className="border border-border/50">
            <CardHeader>
              <CardTitle className="text-lg font-bold text-foreground">Recent Activity</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {recentActivity.map((activity, index) => (
                  <div key={index} className="flex items-start gap-3">
                    <div className="w-2 h-2 rounded-full bg-primary mt-2 flex-shrink-0" />
                    <div className="flex-1">
                      <p className="text-sm text-foreground">{activity.action}</p>
                      <p className="text-xs text-muted-foreground">{activity.time}</p>
                    </div>
                  </div>
                ))}
              </div>
              <Button variant="outline" className="w-full mt-4">
                View All Activity
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    </section>
  );
};

export default DashboardOverview;