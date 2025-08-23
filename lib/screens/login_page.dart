import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import 'signup_page.dart';
import 'dashboard.dart';

class LoginPage extends StatefulWidget {
  static const route = '/login';
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    final ok = await DBHelper.instance.verifyUser(email, pass);
    if (!mounted) return;

    if (ok) {
      // Fetch the full user so we can pass userId/displayName forward.
      final user = await DBHelper.instance.getUserByEmail(email);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful!')),
      );

      final userId = user?.id ?? 1;
      final friendlyName = user?.name ?? email.split('@').first;
      final userEmail = user?.email ?? email;

      // 🔑 Superadmin check: send to /admin if email is admin@gmail.com
      final isSuperAdmin = userEmail.toLowerCase() == 'admin@gmail.com';

      if (isSuperAdmin) {
        // NOTE: No import of admin.dart here; just navigate by route name.
        // Make sure you register '/admin' in MaterialApp routes when you add AdminPage.
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/admin',
              (_) => false,
          arguments: {
            'displayName': friendlyName,
            'email': userEmail,
            'userId': userId,
          },
        );
      } else {
        // Default: go to Dashboard
        Navigator.pushNamedAndRemoveUntil(
          context,
          DashboardPage.route,
              (_) => false,
          arguments: {
            'displayName': friendlyName,
            'email': userEmail,
            'userId': userId,
          },
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid credentials')),
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text('Welcome back', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter password' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Login'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    SignupPage.route,
                  ),
                  child: const Text('No account? Sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
