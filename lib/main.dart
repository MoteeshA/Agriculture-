import 'package:flutter/material.dart';

import 'screens/welcome.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/dashboard.dart'; // <-- added

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
      initialRoute: WelcomeScreen.route, // unchanged
      routes: {
        WelcomeScreen.route: (_) => const WelcomeScreen(),
        LoginPage.route:     (_) => const LoginPage(),
        SignupPage.route:    (_) => const SignupPage(),
        DashboardPage.route: (_) => const DashboardPage(), // <-- added
      },
    );
  }
}
