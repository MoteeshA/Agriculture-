import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { TrendingUp, MapPin, Calendar, Loader2, Target, BarChart3 } from "lucide-react";
import { useState } from "react";
import IndiaMap from "@/components/IndiaMap";
import {
  fetchNearbyMarketPrices,
  generatePricePrediction,
  fetchAllMandiPrices,
  fetchLastTwoPrices,
  type MarketPrice,
  type PricePrediction,
} from "@/services/priceService";

const indianStates = [
  "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh",
  "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka",
  "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram",
  "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu",
  "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal",
  "Delhi", "Chandigarh", "Puducherry", "Jammu and Kashmir", "Ladakh"
];

const CropPriceSection = () => {
  const [selectedCrop, setSelectedCrop] = useState("wheat");
  const [selectedPeriod, setSelectedPeriod] = useState("current");
  const [location, setLocation] = useState("");
  const [mandiLocation, setMandiLocation] = useState("");
  const [nearbyMarkets, setNearbyMarkets] = useState<MarketPrice[]>([]);
  const [allMandiPrices, setAllMandiPrices] = useState<MarketPrice[]>([]);
  const [lastTwoPrices, setLastTwoPrices] = useState<MarketPrice[]>([]);
  const [prediction, setPrediction] = useState<PricePrediction | null>(null);
  const [loading, setLoading] = useState(false);
  const [predictionLoading, setPredictionLoading] = useState(false);
  const [mandiLoading, setMandiLoading] = useState(false);

  const handleGetNearbyMarkets = async () => {
    if (!selectedCrop || !location) return;
    setLoading(true);
    try {
      const markets = await fetchNearbyMarketPrices(selectedCrop, location);
      setNearbyMarkets(markets);
    } catch (error) {
      console.error("Error fetching nearby markets:", error);
    }
    setLoading(false);
  };

  const handleGetPrediction = async () => {
    if (!selectedCrop || !location) return;
    setPredictionLoading(true);
    try {
      const predictionResult = await generatePricePrediction(selectedCrop, location, selectedPeriod);
      setPrediction(predictionResult);

      // 🔹 Fetch last 2 mandi prices
      const last2 = await fetchLastTwoPrices(selectedCrop, location);
      setLastTwoPrices(last2);
    } catch (error) {
      console.error("Error generating prediction:", error);
    }
    setPredictionLoading(false);
  };

  const handleGetMandiPrices = async () => {
    if (!mandiLocation) return;
    setMandiLoading(true);
    try {
      const mandiPrices = await fetchAllMandiPrices(mandiLocation, selectedPeriod);
      setAllMandiPrices(mandiPrices);
    } catch (error) {
      console.error("Error fetching mandi prices:", error);
    }
    setMandiLoading(false);
  };

  return (
    <section className="py-20 px-6 bg-muted/30">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold text-foreground mb-6">
            Real-time
            <span className="block bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
              Crop Prices
            </span>
          </h2>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Get accurate, up-to-date market prices from mandis across India with AI-powered predictions
          </p>
        </div>

        {/* Main Grid */}
        <div className="grid xl:grid-cols-3 lg:grid-cols-2 gap-8 items-start">
          {/* Price Prediction Form */}
          <Card className="border-2 border-primary/20 shadow-medium">
            <CardHeader className="bg-gradient-to-r from-primary/5 to-accent/5">
              <CardTitle className="text-2xl font-bold text-foreground flex items-center gap-3">
                <TrendingUp className="w-6 h-6 text-primary" />
                Price Prediction
              </CardTitle>
            </CardHeader>
            <CardContent className="p-6">
              <div className="space-y-4">
                {/* Crop Select */}
                <div>
                  <label className="text-sm font-medium text-foreground mb-2 block">Select Crop</label>
                  <select
                    value={selectedCrop}
                    onChange={(e) => setSelectedCrop(e.target.value)}
                    className="w-full p-3 border border-border rounded-lg bg-background text-foreground"
                  >
                    <option value="wheat">Wheat</option>
                    <option value="rice">Rice</option>
                    <option value="cotton">Cotton</option>
                    <option value="sugarcane">Sugarcane</option>
                  </select>
                </div>

                {/* State Select */}
                <div>
                  <label className="text-sm font-medium text-foreground mb-2 block flex items-center gap-2">
                    <MapPin className="w-4 h-4" />
                    Select State
                  </label>
                  <Select value={location} onValueChange={setLocation}>
                    <SelectTrigger className="w-full">
                      <SelectValue placeholder="Choose your state" />
                    </SelectTrigger>
                    <SelectContent className="max-h-60">
                      {indianStates.map((state) => (
                        <SelectItem key={state} value={state}>
                          {state}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {/* Period Select */}
                <div>
                  <label className="text-sm font-medium text-foreground mb-2 block flex items-center gap-2">
                    <Calendar className="w-4 h-4" />
                    Prediction Period
                  </label>
                  <select
                    value={selectedPeriod}
                    onChange={(e) => setSelectedPeriod(e.target.value)}
                    className="w-full p-3 border border-border rounded-lg bg-background text-foreground"
                  >
                    <option value="current">Current Price</option>
                    <option value="7days">Next 7 days</option>
                    <option value="15days">Next 15 days</option>
                    <option value="30days">Next 30 days</option>
                  </select>
                </div>

                {/* Buttons */}
                <div className="flex gap-2 mt-6">
                  <Button onClick={handleGetNearbyMarkets} disabled={!selectedCrop || !location || loading} className="flex-1" variant="outline">
                    {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <MapPin className="w-4 h-4" />}
                    Nearby Markets
                  </Button>
                  <Button onClick={handleGetPrediction} disabled={!selectedCrop || !location || predictionLoading} variant="agricultural" className="flex-1">
                    {predictionLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Target className="w-4 h-4" />}
                    Predict Price
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* India Map */}
          <div className="xl:col-span-1 lg:col-span-2">
            <IndiaMap selectedCrop={selectedCrop} selectedPeriod={selectedPeriod} />
          </div>

          {/* Market Prices & Predictions */}
          <div className="space-y-6">
            {/* Nearby Markets */}
            {nearbyMarkets.length > 0 && (
              <div>
                <h3 className="text-2xl font-bold text-foreground mb-4 flex items-center gap-2">
                  <MapPin className="w-6 h-6 text-primary" />
                  Nearby Markets
                </h3>
                <div className="space-y-3">
                  {nearbyMarkets.slice(0, 5).map((market, index) => (
                    <Card key={index} className="border border-border/50 hover:border-primary/30">
                      <CardContent className="p-4">
                        <div className="flex justify-between items-center">
                          <div>
                            <h4 className="font-semibold text-foreground">{market.market}</h4>
                            <p className="text-sm text-muted-foreground">{market.commodity}</p>
                            <p className="text-xs text-muted-foreground">{market.arrival_date}</p>
                          </div>
                          <div className="text-right">
                            <p className="font-bold text-lg text-foreground">₹{Math.round(parseFloat(market.modal_price))}</p>
                            <p className="text-sm text-muted-foreground">
                              ₹{Math.round(parseFloat(market.min_price))} - ₹{Math.round(parseFloat(market.max_price))}
                            </p>
                          </div>
                        </div>
                      </CardContent>
                    </Card>
                  ))}
                </div>
              </div>
            )}

            {/* Prediction Results */}
            {prediction && (
              <div>
                <h3 className="text-2xl font-bold text-foreground mb-4 flex items-center gap-2">
                  <BarChart3 className="w-6 h-6 text-primary" />
                  {prediction.period === "Current" ? "Current Price" : "Price Prediction"}
                </h3>
                <Card className="border-2 border-primary/20">
                  <CardContent className="p-6">
                    <div className="flex justify-between items-start">
                      <div>
                        <h4 className="text-xl font-bold text-foreground capitalize">{prediction.crop}</h4>
                        <p className="text-muted-foreground">{prediction.location} • {prediction.period}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-3xl font-bold text-primary">{prediction.predictedPrice}</p>
                        <p className="text-sm text-muted-foreground">{prediction.confidence} confidence</p>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}
          </div>
        </div>

        {/* 🔹 Current Rates Section */}
        <div className="mt-16">
          <div className="mb-6 flex gap-4 items-center">
            <h3 className="text-2xl font-bold text-foreground">Current Rates</h3>
            <Select value={mandiLocation} onValueChange={setMandiLocation}>
              <SelectTrigger className="w-48">
                <SelectValue placeholder="Select state" />
              </SelectTrigger>
              <SelectContent className="max-h-60">
                {indianStates.map((state) => (
                  <SelectItem key={state} value={state}>
                    {state}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>

            <Select value={selectedPeriod} onValueChange={setSelectedPeriod}>
              <SelectTrigger className="w-40">
                <SelectValue placeholder="Select period" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="today">Today's Price</SelectItem>
                <SelectItem value="7days">Last 7 Days</SelectItem>
                <SelectItem value="15days">Last 15 Days</SelectItem>
                <SelectItem value="all">All Data</SelectItem>
              </SelectContent>
            </Select>

            <Button onClick={handleGetMandiPrices} disabled={!mandiLocation || mandiLoading} variant="outline">
              {mandiLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : "Get Prices"}
            </Button>
          </div>

          {/* Table of Mandi Prices */}
          {allMandiPrices.length > 0 && (
            <div className="overflow-x-auto border rounded-lg">
              <table className="w-full text-sm">
                <thead className="bg-muted">
                  <tr>
                    <th className="p-2 text-left">Date</th>
                    <th className="p-2 text-left">State</th>
                    <th className="p-2 text-left">District</th>
                    <th className="p-2 text-left">Market</th>
                    <th className="p-2 text-left">Commodity</th>
                    <th className="p-2 text-right">Min</th>
                    <th className="p-2 text-right">Max</th>
                    <th className="p-2 text-right">Modal</th>
                  </tr>
                </thead>
                <tbody>
                  {allMandiPrices.slice(0, 100).map((row, index) => (
                    <tr key={index} className="border-t">
                      <td className="p-2">{row.arrival_date}</td>
                      <td className="p-2">{row.state}</td>
                      <td className="p-2">{row.district}</td>
                      <td className="p-2">{row.market}</td>
                      <td className="p-2">{row.commodity}</td>
                      <td className="p-2 text-right">₹{row.min_price}</td>
                      <td className="p-2 text-right">₹{row.max_price}</td>
                      <td className="p-2 text-right font-bold">₹{row.modal_price}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {allMandiPrices.length === 0 && !mandiLoading && (
            <div className="text-center py-8 text-muted-foreground">
              <p>Select a state and period to see mandi prices</p>
            </div>
          )}
        </div>
      </div>
    </section>
  );
};

export default CropPriceSection;
