import FarmingHero from "@/components/FarmingHero";
import FeaturesGrid from "@/components/FeaturesGrid";
import DashboardOverview from "@/components/DashboardOverview";

const FarmingApp = () => {
  return (
    <div className="min-h-screen">
      <FarmingHero />
      <FeaturesGrid />
      <DashboardOverview />
    </div>
  );
};

export default FarmingApp;