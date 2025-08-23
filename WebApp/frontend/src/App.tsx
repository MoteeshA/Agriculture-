import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import Index from "./pages/Index";
import NotFound from "./pages/NotFound";
import FarmingApp from "./pages/FarmingApp";
import CropPrices from "./pages/CropPrices";
import Equipment from "./pages/Equipment";
import CropHealth from "./pages/CropHealth";
import Schemes from "./pages/Schemes";
import CropRecommendationPage from "./pages/CropRecommendation";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<FarmingApp />} />
          <Route path="/crop-recommendation" element={<CropRecommendationPage />} />
          <Route path="/crop-prices" element={<CropPrices />} />
          <Route path="/equipment" element={<Equipment />} />
          <Route path="/crop-health" element={<CropHealth />} />
          <Route path="/schemes" element={<Schemes />} />
          {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
          <Route path="*" element={<NotFound />} />
        </Routes>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
