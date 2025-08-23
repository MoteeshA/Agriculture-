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
  late AnimationController _controller;
  late Animation<Offset> _buttonAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _buttonAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Simple staged animation
    Timer(const Duration(milliseconds: 200), () {
      setState(() => _visible = true);
    });
    Timer(const Duration(milliseconds: 600), () {
      setState(() => _scaled = true);
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FDF9),
      body: SafeArea(
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -size.width * 0.2,
              right: -size.width * 0.1,
              child: Container(
                width: size.width * 0.6,
                height: size.width * 0.6,
                decoration: BoxDecoration(
                  color: const Color(0xFF0fb15d).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -size.width * 0.3,
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  color: const Color(0xFF0fb15d).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Center(
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
                            // App logo with subtle shadow
                            Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.1),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: Image.asset(
                                'assets/agrimitra.png',
                                width: 180,
                                height: 180,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // App title
                            Text(
                              'One Stop Farmer Ecosystem',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFF0fb15d),
                                fontWeight: FontWeight.bold,
                                fontSize: 21,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Tagline
                            Text(
                              'Smart tools for Indian farmers',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.black54,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Buttons with slide animation
                    SlideTransition(
                      position: _buttonAnimation,
                      child: Column(
                        children: [
                          // Login button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.pushNamed(context, LoginPage.route),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0fb15d),
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Sign up button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pushNamed(context, SignupPage.route),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFF0fb15d),
                                  width: 1.5,
                                ),
                              ),
                              child: const Text(
                                'Create an account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0fb15d),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}