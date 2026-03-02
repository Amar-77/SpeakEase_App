import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);

    String? error = await _authService.signInUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
    // If success, AuthWrapper in main.dart handles navigation
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mic, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text("SpeakEase", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
            ),

            //Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                  );
                },
                child: const Text(
                  "Forgot Password?",
                ),
              ),
            ),
            const SizedBox(height: 20),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _handleLogin,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              child: const Text("Login"),
            ),

            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
              },
              child: const Text("Don't have an account? Join Class"),
            ),
          ],
        ),
      ),
    );
  }
}