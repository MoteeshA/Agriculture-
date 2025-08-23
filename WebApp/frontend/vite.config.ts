import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import path from "path";
import { componentTagger } from "lovable-tagger";

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => ({
  server: {
    host: "::",
    port: 8080,
    proxy: {
      // 🔹 Forward API calls to Flask (port 5000)
      "/predict": "http://127.0.0.1:5000",
      "/detect_disease": "http://127.0.0.1:5000",
      "/get_price": "http://127.0.0.1:5000",
      "/get_schemes": "http://127.0.0.1:5000",
    },
  },
  plugins: [
    react(),
    mode === "development" && componentTagger(),
  ].filter(Boolean),
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
}));
