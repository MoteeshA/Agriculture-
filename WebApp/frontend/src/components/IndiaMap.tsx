import { useState } from "react";
import { Card, CardContent } from "@/components/ui/card";

const stateData = [
  { id: "punjab", name: "Punjab", price: "₹2,150", change: "+5.2%", x: 120, y: 80, width: 80, height: 50 },
  { id: "haryana", name: "Haryana", price: "₹3,420", change: "-2.1%", x: 140, y: 130, width: 70, height: 40 },
  { id: "gujarat", name: "Gujarat", price: "₹5,680", change: "+8.7%", x: 80, y: 200, width: 90, height: 80 },
  { id: "maharashtra", name: "Maharashtra", price: "₹350", change: "+3.4%", x: 170, y: 240, width: 100, height: 70 },
  { id: "rajasthan", name: "Rajasthan", price: "₹1,890", change: "+2.8%", x: 60, y: 140, width: 110, height: 100 },
  { id: "madhya-pradesh", name: "Madhya Pradesh", price: "₹2,340", change: "+1.5%", x: 170, y: 180, width: 120, height: 60 },
  { id: "uttar-pradesh", name: "Uttar Pradesh", price: "₹2,280", change: "+4.1%", x: 200, y: 100, width: 120, height: 80 },
  { id: "karnataka", name: "Karnataka", price: "₹4,120", change: "+6.3%", x: 160, y: 310, width: 80, height: 70 },
  { id: "telangana", name: "Telangana", price: "₹3,890", change: "+3.7%", x: 240, y: 270, width: 70, height: 50 },
  { id: "andhra-pradesh", name: "Andhra Pradesh", price: "₹3,650", change: "+2.9%", x: 240, y: 320, width: 80, height: 70 },
  { id: "tamil-nadu", name: "Tamil Nadu", price: "₹4,560", change: "+5.8%", x: 200, y: 380, width: 80, height: 70 },
  { id: "kerala", name: "Kerala", price: "₹4,890", change: "+7.2%", x: 160, y: 410, width: 50, height: 60 },
  { id: "west-bengal", name: "West Bengal", price: "₹2,890", change: "+3.1%", x: 320, y: 200, width: 60, height: 80 },
  { id: "bihar", name: "Bihar", price: "₹2,120", change: "+2.5%", x: 290, y: 150, width: 70, height: 50 },
  { id: "odisha", name: "Odisha", price: "₹3,240", change: "+4.8%", x: 310, y: 250, width: 70, height: 70 },
  { id: "assam", name: "Assam", price: "₹2,567", change: "+3.9%", x: 380, y: 180, width: 60, height: 40 },
  { id: "chhattisgarh", name: "Chhattisgarh", price: "₹2,450", change: "+2.7%", x: 270, y: 220, width: 70, height: 50 },
  { id: "jharkhand", name: "Jharkhand", price: "₹2,340", change: "+1.8%", x: 320, y: 180, width: 60, height: 40 },
];

interface IndiaMapProps {
  selectedCrop: string;
  selectedPeriod: string;
}

const IndiaMap = ({ selectedCrop, selectedPeriod }: IndiaMapProps) => {
  const [hoveredState, setHoveredState] = useState<string | null>(null);
  const [selectedState, setSelectedState] = useState<string | null>(null);

  const getStateColor = (change: string) => {
    const value = parseFloat(change.replace(/[+%]/g, ''));
    if (value > 5) return "fill-green-500/70 hover:fill-green-500";
    if (value > 0) return "fill-yellow-500/70 hover:fill-yellow-500";
    return "fill-red-500/70 hover:fill-red-500";
  };

  const selectedStateData = selectedState ? stateData.find(s => s.id === selectedState) : null;

  return (
    <div className="space-y-4">
      <Card className="border-2 border-primary/20">
        <CardContent className="p-6">
          <div className="text-center mb-4">
            <h3 className="text-xl font-semibold text-foreground mb-2">
              {selectedCrop.charAt(0).toUpperCase() + selectedCrop.slice(1)} Prices - {selectedPeriod}
            </h3>
            <p className="text-sm text-muted-foreground">Click on states to view detailed price information</p>
          </div>
          
          <div className="relative border border-border rounded-lg overflow-hidden bg-muted">
            <svg
              viewBox="0 0 500 520"
              className="w-full h-auto max-h-96"
              style={{ backgroundColor: 'hsl(var(--muted))' }}
            >
              {/* India outline - simplified shape */}
              <path
                d="M100,120 L160,80 L220,85 L280,90 L340,100 L380,120 L420,140 L440,180 L430,220 L400,260 L380,300 L350,340 L320,380 L280,420 L240,450 L200,460 L160,450 L140,420 L120,380 L100,340 L80,300 L70,260 L80,220 L90,180 Z"
                fill="none"
                stroke="hsl(var(--border))"
                strokeWidth="2"
              />
              
              {/* States */}
              {stateData.map((state) => (
                <g key={state.id}>
                  <rect
                    x={state.x}
                    y={state.y}
                    width={state.width}
                    height={state.height}
                    className={`${getStateColor(state.change)} cursor-pointer stroke-background stroke-1 transition-all duration-200 ${
                      hoveredState === state.id ? 'stroke-2 stroke-foreground' : ''
                    } ${selectedState === state.id ? 'stroke-primary stroke-2' : ''}`}
                    onMouseEnter={() => setHoveredState(state.id)}
                    onMouseLeave={() => setHoveredState(null)}
                    onClick={() => setSelectedState(state.id === selectedState ? null : state.id)}
                    rx="4"
                  />
                  
                  {/* State name */}
                  <text
                    x={state.x + state.width / 2}
                    y={state.y + state.height / 2 - 8}
                    className="text-xs fill-foreground font-semibold pointer-events-none select-none"
                    textAnchor="middle"
                    style={{ fontSize: '10px' }}
                  >
                    {state.name.length > 10 ? state.name.split(' ')[0] : state.name}
                  </text>
                  
                  {/* Price */}
                  <text
                    x={state.x + state.width / 2}
                    y={state.y + state.height / 2 + 4}
                    className="text-xs fill-foreground font-bold pointer-events-none select-none"
                    textAnchor="middle"
                    style={{ fontSize: '9px' }}
                  >
                    {state.price}
                  </text>
                  
                  {/* Change percentage */}
                  <text
                    x={state.x + state.width / 2}
                    y={state.y + state.height / 2 + 16}
                    className={`text-xs font-medium pointer-events-none select-none ${
                      state.change.startsWith('+') ? 'fill-green-600' : 'fill-red-600'
                    }`}
                    textAnchor="middle"
                    style={{ fontSize: '8px' }}
                  >
                    {state.change}
                  </text>
                </g>
              ))}
              
              {/* Hover tooltip */}
              {hoveredState && (
                <g>
                  <rect
                    x="10"
                    y="10"
                    width="140"
                    height="80"
                    fill="hsl(var(--popover))"
                    stroke="hsl(var(--border))"
                    strokeWidth="1"
                    rx="4"
                  />
                  <text x="20" y="30" className="text-sm fill-foreground font-semibold">
                    {stateData.find(s => s.id === hoveredState)?.name}
                  </text>
                  <text x="20" y="50" className="text-sm fill-foreground">
                    Price: {stateData.find(s => s.id === hoveredState)?.price}
                  </text>
                  <text x="20" y="70" className="text-sm fill-foreground">
                    Change: {stateData.find(s => s.id === hoveredState)?.change}
                  </text>
                </g>
              )}
            </svg>
          </div>

          {/* Legend */}
          <div className="flex justify-center items-center gap-6 mt-4 text-xs">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 bg-green-500 rounded"></div>
              <span className="text-muted-foreground">Price Increase &gt; 5%</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 bg-yellow-500 rounded"></div>
              <span className="text-muted-foreground">Price Increase 0-5%</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 bg-red-500 rounded"></div>
              <span className="text-muted-foreground">Price Decrease</span>
            </div>
          </div>

          {/* Selected state details */}
          {selectedStateData && (
            <Card className="mt-4 border border-primary/30 bg-primary/5">
              <CardContent className="p-4">
                <h4 className="font-semibold text-foreground text-lg mb-2">{selectedStateData.name}</h4>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-sm text-muted-foreground">Current Price</p>
                    <p className="font-bold text-lg text-foreground">{selectedStateData.price}</p>
                  </div>
                  <div>
                    <p className="text-sm text-muted-foreground">Price Change</p>
                    <p className={`font-semibold text-lg ${
                      selectedStateData.change.startsWith('+') ? 'text-green-600' : 'text-red-600'
                    }`}>
                      {selectedStateData.change}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}
        </CardContent>
      </Card>
    </div>
  );
};

export default IndiaMap;