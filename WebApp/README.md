# 🌾 KrishiMitra – One-Stop Farmer Ecosystem  

KrishiMitra is a **One-Stop Digital Solution** designed to empower farmers by addressing challenges such as **unfair pricing, high equipment costs, counterfeit tools, lack of crop guidance, disease prevention, and scheme awareness**.  

The solution is available as both a **Flutter Mobile App** and a **React Web Platform**, ensuring accessibility across devices.  

---

## 📌 Features  

- ✅ **Secure User Authentication** – Aadhaar/PAN-based KYC to ensure legitimate users.  
- ✅ **Equipment Rental & Lending** – Farmers can rent or lend agricultural equipment to reduce costs.  
- ✅ **Product Certification & Compliance** – Certified label for genuine equipment.  
- ✅ **Soil-Based Crop Recommendation** – Suggests the most suitable crops based on soil parameters.  
- ✅ **Crop Disease Detection** – AI-powered detection and advisory from crop images.  
- ✅ **Commodity Price Aggregation & Analytics** – Real-time and historical mandi prices with trends.  
- ✅ **Interactive India Map Visualization** – State-wise and nationwide crop price transparency.  
- ✅ **Government Schemes Integration** – Personalized scheme recommendations using MyScheme/AgriWelfare APIs.  

---

## 🛠️ Problem–Solution Mapping  

| **Problem Faced by Farmers** | **Our Solution – KrishiMitra** |
|-------------------------------|--------------------------------|
| Unfair Pricing | Real-time + historical mandi prices with analytics and India map view |
| High Equipment Costs | Rental & lending marketplace for agricultural tools |
| Counterfeit Products | Certified label system + Aadhaar/PAN verification |
| Lack of Crop Guidance | Soil-data-based crop recommendation |
| Crop Losses Due to Diseases | AI-powered disease detection & treatment suggestions |
| Low Awareness of Schemes | Integrated government schemes portal |

---

## ⚙️ Tech Stack  

| Component | Technology Used |
|-----------|-----------------|
| Mobile App | Flutter |
| Web App | React |
| Database | SQLite (with user sync) |
| Backend / APIs | Flask / FastAPI |
| AI/ML Models | Crop Recommendation, Disease Detection, Price Prediction |
| Security | Aadhaar/PAN verification, Encrypted login |
| Integrations | MyScheme API, AgriWelfare API, Govt. Mandi Price APIs |

---

## 🚀 Deployment Readiness  

- 📱 **Mobile App:** Built in Flutter, with SQLite database and real-time sync.  
- 💻 **Web App:** React-based, lightweight, responsive, and accessible.  
- 🔒 **Security:** Aadhaar/PAN-based login ensures only verified users.  
- 🗺️ **Visualization:** Real-time India Map for nationwide crop price insights.  

---

## 📽️ Demo & Access  

- 🎥 [YouTube Demo 1](https://www.youtube.com/watch?v=XXXXX)  
- 🎥 [YouTube Demo 2](https://www.youtube.com/watch?v=YYYYY)  
- 📲 [Download APK](https://example.com/krishimitra.apk)  
- 🌐 [Live Website](https://example.com/krishimitra)  

---

## 📂 Setup Instructions  

### 🔹 Backend (Flask / FastAPI)
```bash
# Clone repo
git clone https://github.com/your-repo/krishimitra.git

cd krishimitra/backend             # Navigate to backend folder
python -m venv venv                # Create virtual environment (recommended)
venv\Scripts\activate              # Activate venv (Windows)
pip install -r requirements.txt    # Install dependencies
python app.py                      # Run backend server

cd ../frontend                     # Navigate to frontend folder
npm i                              # Install dependencies
npm run dev                        # Start development server (Vite) / use npm start if CRA

cd ../mobile                       # Navigate to Flutter app folder
flutter pub get                    # Get dependencies
flutter run                        # Run app on emulator / device
