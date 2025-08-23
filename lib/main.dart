import 'package:flutter/material.dart';

import 'screens/welcome.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/dashboard.dart';
import 'screens/crop_prices.dart';
import 'screens/rent.dart';
import 'screens/admin.dart';
import 'screens/disease.dart'; // <-- disease detection screen
import 'screens/govt.dart';    // <-- NEW: govt schemes screen

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AgriMitraApp());
}

class AgriMitraApp extends StatelessWidget {
  const AgriMitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriMitra',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0fb15d)),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: WelcomeScreen.route,
      routes: {
        WelcomeScreen.route: (_)   => const WelcomeScreen(),
        LoginPage.route:     (_)   => const LoginPage(),
        SignupPage.route:    (_)   => const SignupPage(),
        DashboardPage.route: (_)   => const DashboardPage(),
        CropPricesPage.route: (_)  => const CropPricesPage(),
        RentPage.route:      (_)   => const RentPage(),
        DiseasePage.route:   (_)   => const DiseasePage(),
        GovtPage.route:      (_)   => const GovtPage(),   // ✅ NEW
        '/admin':            (_)   => const AdminPage(),
      },
    );
  }
}
