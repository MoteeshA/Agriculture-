export type MarketPrice = {
  arrival_date: string;
  state: string;
  district: string;
  market: string;
  commodity: string;
  min_price: string;
  max_price: string;
  modal_price: string;
};

export type PricePrediction = {
  crop: string;
  location: string;
  period: string;
  predictedPrice: string;
  confidence: string;
  trend: string;
  factors: string[];
};

// Fetch mandi prices by state + filter
export async function fetchAllMandiPrices(state: string, filter: string): Promise<MarketPrice[]> {
  const res = await fetch(`http://127.0.0.1:5000/get_price?state=${encodeURIComponent(state)}&filter=${filter}`);
  if (!res.ok) throw new Error("Failed to fetch mandi prices");
  return res.json();
}

// Fetch nearby markets (example: crop + state for today)
export async function fetchNearbyMarketPrices(crop: string, state: string): Promise<MarketPrice[]> {
  const res = await fetch(`http://127.0.0.1:5000/get_price?state=${encodeURIComponent(state)}&commodity=${encodeURIComponent(crop)}&filter=today`);
  if (!res.ok) throw new Error("Failed to fetch nearby markets");
  return res.json();
}

// Generate price prediction
export async function generatePricePrediction(crop: string, location: string, period: string): Promise<PricePrediction> {
  const res = await fetch("http://127.0.0.1:5000/predict_price", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ crop, location, period }),
  });
  if (!res.ok) throw new Error("Failed to generate prediction");
  return res.json();
}

// Fetch last 2 mandi prices for crop+state
export async function fetchLastTwoPrices(crop: string, state: string): Promise<MarketPrice[]> {
  const res = await fetch(`http://127.0.0.1:5000/get_price?state=${encodeURIComponent(state)}&commodity=${encodeURIComponent(crop)}&filter=7days&limit=2`);
  if (!res.ok) throw new Error("Failed to fetch last two prices");
  return res.json();
}
