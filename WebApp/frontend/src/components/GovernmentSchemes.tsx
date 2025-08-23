import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Clock, MapPin, CheckCircle } from "lucide-react";

interface Scheme {
  code: string;
  name: string;
  description: string;
  url: string;
  reason: string;
}

const GovernmentSchemes = () => {
  const [schemes, setSchemes] = useState<Scheme[]>([]);
  const [notes, setNotes] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);

  // Form state
  const [land, setLand] = useState("");
  const [income, setIncome] = useState("");
  const [age, setAge] = useState("");
  const [state, setState] = useState("");
  const [isWoman, setIsWoman] = useState(false);
  const [isSCST, setIsSCST] = useState(false);
  const [isTenant, setIsTenant] = useState(false);
  const [hasBank, setHasBank] = useState(true);

  const checkEligibility = async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({
        land: land || "0",
        income: income || "0",
        age: age || "0",
        state: state || "",
        is_woman: String(isWoman),
        is_scst: String(isSCST),
        is_tenant: String(isTenant),
        has_bank: String(hasBank),
      });

      const res = await fetch(`http://127.0.0.1:5000/find_schemes?${params.toString()}`);
      const data = await res.json();
      setSchemes(data.schemes || []);
      setNotes(data.notes || []);
    } catch (err) {
      console.error("Error fetching schemes:", err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <section className="py-20 px-6 bg-background">
      <div className="max-w-7xl mx-auto grid lg:grid-cols-3 gap-8">
        {/* Eligibility Checker */}
        <div className="lg:col-span-1">
          <Card className="border-2 border-primary/20 shadow-medium sticky top-8">
            <CardHeader className="bg-gradient-to-r from-primary/5 to-accent/5">
              <CardTitle className="flex items-center gap-2 text-xl font-bold">
                <CheckCircle className="w-5 h-5 text-primary" />
                Eligibility Checker
              </CardTitle>
            </CardHeader>
            <CardContent className="p-6 space-y-4">
              <Input
                placeholder="Land Size (acres)"
                value={land}
                onChange={(e) => setLand(e.target.value)}
              />
              <Input
                placeholder="Annual Income (₹)"
                value={income}
                onChange={(e) => setIncome(e.target.value)}
              />
              <Input
                placeholder="Age"
                value={age}
                onChange={(e) => setAge(e.target.value)}
              />

              <div>
                <label className="text-sm font-medium mb-1 block flex items-center gap-2">
                  <MapPin className="w-4 h-4" />
                  State
                </label>
                <select
                  className="w-full p-2 border rounded"
                  value={state}
                  onChange={(e) => setState(e.target.value)}
                >
                  <option value="">Select State</option>
                  <option>Punjab</option>
                  <option>Haryana</option>
                  <option>Gujarat</option>
                  <option>Maharashtra</option>
                  <option>Karnataka</option>
                  <option>Bihar</option>
                  <option>Uttar Pradesh</option>
                  <option>Tamil Nadu</option>
                  <option>Rajasthan</option>
                  <option>Madhya Pradesh</option>
                </select>
              </div>

              {/* Chips / checkboxes */}
              <div className="flex flex-wrap gap-3">
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={isWoman}
                    onChange={(e) => setIsWoman(e.target.checked)}
                  />
                  Woman
                </label>
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={isSCST}
                    onChange={(e) => setIsSCST(e.target.checked)}
                  />
                  SC/ST
                </label>
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={isTenant}
                    onChange={(e) => setIsTenant(e.target.checked)}
                  />
                  Tenant Farmer
                </label>
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={hasBank}
                    onChange={(e) => setHasBank(e.target.checked)}
                  />
                  Has Bank Account
                </label>
              </div>

              <Button onClick={checkEligibility} className="w-full">
                {loading ? "Checking..." : "Check Eligibility"}
              </Button>
            </CardContent>
          </Card>
        </div>

        {/* Schemes List */}
        <div className="lg:col-span-2 space-y-6">
          <h3 className="text-2xl font-bold">Available Schemes</h3>
          {schemes.length === 0 && notes.length === 0 && (
            <p className="text-muted-foreground">
              Fill form and check eligibility to see recommendations
            </p>
          )}

          {/* Schemes */}
          {schemes.map((scheme, i) => (
            <Card key={i} className="border hover:border-primary/30 transition-colors">
              <CardContent className="p-6">
                <div className="flex items-center gap-3 mb-2">
                  <h4 className="font-bold">{scheme.name}</h4>
                  <Badge>{scheme.code}</Badge>
                </div>
                <p className="mb-2">{scheme.description}</p>
                <p className="text-sm text-muted-foreground mb-3">
                  Why: {scheme.reason}
                </p>
                <div className="flex gap-3">
                  <Button
                    variant="agricultural"
                    size="sm"
                    onClick={() => window.open(scheme.url, "_blank")}
                  >
                    Apply Now
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => window.open(scheme.url, "_blank")}
                  >
                    Learn More
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}

          {/* Notes */}
          {notes.length > 0 && (
            <div className="space-y-2">
              {notes.map((note, idx) => (
                <Card key={idx} className="bg-green-50 border-green-200">
                  <CardContent className="p-3 text-sm text-green-800">
                    {note}
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </div>
      </div>
    </section>
  );
};

export default GovernmentSchemes;
