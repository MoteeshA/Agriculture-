import 'dart:async';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'signup_page.dart';

class WelcomeScreen extends StatefulWidget {
  static const route = '/';
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  bool _scaled = false;

  @override
  void initState() {
    super.initState();
    // Simple staged animation
    Timer(const Duration(milliseconds: 200), () {
      setState(() => _visible = true);
    });
    Timer(const Duration(milliseconds: 600), () {
      setState(() => _scaled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FDF9),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 700),
                  child: AnimatedScale(
                    scale: _scaled ? 1.0 : 0.85,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/agrimitra.png',
                          width: 180,
                          height: 180,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'AgriMitra',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: const Color(0xFF0fb15d),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Smart tools for Indian farmers',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, LoginPage.route),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Login'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, SignupPage.route),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFF0fb15d)),
                  ),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
