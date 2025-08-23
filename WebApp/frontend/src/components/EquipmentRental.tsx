import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Slider } from "@/components/ui/slider";
import { MapPin, Calendar, Star, Tractor, Wrench, Scissors, Zap, Filter } from "lucide-react";
import { useState } from "react";

const categories = [
  { id: "all", name: "All Equipment", icon: Zap },
  { id: "vehicles", name: "Vehicles", icon: Tractor },
  { id: "tools", name: "Tools", icon: Wrench },
  { id: "harvesting", name: "Harvesting", icon: Scissors }
];

const mockEquipment = [
  {
    name: "John Deere 5050D Tractor",
    owner: "Ramesh Kumar",
    location: "Ludhiana, Punjab",
    pricePerDay: "₹3,500",
    price: 3500,
    rating: 4.8,
    available: "Available Now",
    image: "🚜",
    category: "vehicles"
  },
  {
    name: "Mahindra 275 DI Tractor",
    owner: "Suresh Singh",
    location: "Karnal, Haryana", 
    pricePerDay: "₹2,800",
    price: 2800,
    rating: 4.6,
    available: "Available from Mar 15",
    image: "🚜",
    category: "vehicles"
  },
  {
    name: "Combine Harvester",
    owner: "Farmers Co-op",
    location: "Amritsar, Punjab",
    pricePerDay: "₹8,500",
    price: 8500,
    rating: 4.9,
    available: "Available Now", 
    image: "🌾",
    category: "harvesting"
  },
  {
    name: "Rotary Tiller",
    owner: "Vikram Tools",
    location: "Chandigarh, Punjab",
    pricePerDay: "₹1,200",
    price: 1200,
    rating: 4.5,
    available: "Available Now",
    image: "🔧",
    category: "tools"
  },
  {
    name: "Seed Drill Machine",
    owner: "Agri Solutions",
    location: "Hisar, Haryana",
    pricePerDay: "₹2,200",
    price: 2200,
    rating: 4.7,
    available: "Available Now",
    image: "🌱",
    category: "tools"
  },
  {
    name: "Rice Harvester",
    owner: "Green Fields Co-op",
    location: "Patiala, Punjab",
    pricePerDay: "₹7,200",
    price: 7200,
    rating: 4.8,
    available: "Available from Mar 20",
    image: "🌾",
    category: "harvesting"
  }
];

const EquipmentRental = () => {
  const [selectedCategory, setSelectedCategory] = useState("all");
  const [selectedLocation, setSelectedLocation] = useState("all");
  const [priceRange, setPriceRange] = useState([1000, 10000]);
  const [availabilityFilter, setAvailabilityFilter] = useState("all");

  // Extract unique locations
  const locations = Array.from(new Set(mockEquipment.map(eq => eq.location.split(', ')[1]))).sort();

  const filteredEquipment = mockEquipment.filter(equipment => {
    const categoryMatch = selectedCategory === "all" || equipment.category === selectedCategory;
    const locationMatch = selectedLocation === "all" || equipment.location.includes(selectedLocation);
    const priceMatch = equipment.price >= priceRange[0] && equipment.price <= priceRange[1];
    const availabilityMatch = availabilityFilter === "all" || 
      (availabilityFilter === "available" && equipment.available === "Available Now") ||
      (availabilityFilter === "upcoming" && equipment.available !== "Available Now");
    
    return categoryMatch && locationMatch && priceMatch && availabilityMatch;
  });

  return (
    <section className="py-20 px-6 bg-background">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl font-bold text-foreground mb-6">
            Equipment
            <span className="block bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
              Marketplace
            </span>
          </h2>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Rent tractors, harvesters, and other farming equipment from trusted farmers in your area
          </p>
        </div>

        {/* Category Filters */}
        <div className="flex flex-wrap justify-center gap-4 mb-8">
          {categories.map((category) => {
            const IconComponent = category.icon;
            return (
              <Button
                key={category.id}
                variant={selectedCategory === category.id ? "agricultural" : "outline"}
                size="lg"
                onClick={() => setSelectedCategory(category.id)}
                className="flex items-center gap-2 min-w-[140px]"
              >
                <IconComponent className="w-5 h-5" />
                {category.name}
              </Button>
            );
          })}
        </div>

        {/* Additional Filters */}
        <div className="bg-muted/30 border border-border/50 rounded-xl p-6 mb-12">
          <div className="flex items-center gap-2 mb-6">
            <Filter className="w-5 h-5 text-muted-foreground" />
            <h3 className="text-lg font-semibold text-foreground">Filters</h3>
          </div>
          
          <div className="grid md:grid-cols-3 gap-6">
            {/* Location Filter */}
            <div className="space-y-2">
              <label className="text-sm font-medium text-foreground">Location</label>
              <Select value={selectedLocation} onValueChange={setSelectedLocation}>
                <SelectTrigger>
                  <SelectValue placeholder="Select state" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Locations</SelectItem>
                  {locations.map((location) => (
                    <SelectItem key={location} value={location}>
                      {location}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Price Range Filter */}
            <div className="space-y-2">
              <label className="text-sm font-medium text-foreground">
                Price Range: ₹{priceRange[0].toLocaleString()} - ₹{priceRange[1].toLocaleString()}
              </label>
              <Slider
                value={priceRange}
                onValueChange={setPriceRange}
                max={10000}
                min={1000}
                step={500}
                className="pt-2"
              />
            </div>

            {/* Availability Filter */}
            <div className="space-y-2">
              <label className="text-sm font-medium text-foreground">Availability</label>
              <Select value={availabilityFilter} onValueChange={setAvailabilityFilter}>
                <SelectTrigger>
                  <SelectValue placeholder="Select availability" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Equipment</SelectItem>
                  <SelectItem value="available">Available Now</SelectItem>
                  <SelectItem value="upcoming">Available Later</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </div>

        {/* Equipment Grid */}
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
          {filteredEquipment.map((equipment, index) => (
            <Card key={index} className="border-2 border-border/50 hover:border-primary/30 transition-all duration-300 hover:shadow-medium group">
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="text-4xl mb-2">{equipment.image}</div>
                  <Badge variant="outline" className="bg-accent/10 text-accent border-accent/20">
                    {equipment.available}
                  </Badge>
                </div>
                <CardTitle className="text-xl font-bold text-foreground group-hover:text-primary transition-colors">
                  {equipment.name}
                </CardTitle>
                <CardDescription className="text-muted-foreground">
                  Owner: {equipment.owner}
                </CardDescription>
              </CardHeader>
              
              <CardContent className="space-y-4">
                <div className="flex items-center gap-2 text-sm text-muted-foreground">
                  <MapPin className="w-4 h-4" />
                  {equipment.location}
                </div>
                
                <div className="flex items-center gap-2">
                  <Star className="w-4 h-4 text-accent fill-current" />
                  <span className="text-sm font-medium text-foreground">{equipment.rating}</span>
                  <span className="text-sm text-muted-foreground">(24 reviews)</span>
                </div>
                
                <div className="flex items-center justify-between pt-4 border-t border-border">
                  <div>
                    <p className="text-2xl font-bold text-foreground">{equipment.pricePerDay}</p>
                    <p className="text-sm text-muted-foreground">per day</p>
                  </div>
                  <Button variant="agricultural">
                    Rent Now
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        {filteredEquipment.length === 0 && (
          <div className="text-center py-12">
            <p className="text-lg text-muted-foreground">No equipment found in this category.</p>
          </div>
        )}

        <div className="text-center mt-12">
          <Button variant="outline" size="lg">
            View All Equipment
          </Button>
        </div>
      </div>
    </section>
  );
};

export default EquipmentRental;