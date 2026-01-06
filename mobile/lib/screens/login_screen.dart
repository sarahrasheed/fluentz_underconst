import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'forgot_password_screen.dart';
import '../theme/fluentz_colors.dart';
import '../widgets/auth_shell.dart';
import 'register_screen.dart';
import '../widgets/auth_feedback.dart';
import 'MatchingResultsScreen.dart';

/// TEMP page after login (until Home is built)
class AfterLoginScreen extends StatelessWidget {
  const AfterLoginScreen({super.key, required this.userJson});

  final Map<String, dynamic> userJson;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FluentzColors.lightYellow,
      appBar: AppBar(
        backgroundColor: FluentzColors.lightYellow,
        elevation: 0,
        title: const Text(
          "Logged in",
          style: TextStyle(color: FluentzColors.navy),
        ),
        iconTheme: const IconThemeData(color: FluentzColors.navy),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "✅ Login Success",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: FluentzColors.navy,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "User: ${userJson["email"] ?? userJson["name"] ?? userJson["id"] ?? ""}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FluentzColors.navy.withOpacity(0.75),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "Home page comes later.",
                style: TextStyle(
                  color: FluentzColors.navy.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  // Change this only if your backend uses a different port
  static const int _backendPort = 8000;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: FluentzColors.navy.withOpacity(0.75)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFFBFBFC),
      labelStyle: TextStyle(color: FluentzColors.navy.withOpacity(0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: FluentzColors.navy.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: FluentzColors.navy.withOpacity(0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: FluentzColors.lightBlue, width: 1.6),
      ),
    );
  }

  String _baseUrl() {
    // Chrome/web can call localhost directly.
    if (kIsWeb) return "http://127.0.0.1:$_backendPort";
    // Android emulator must use 10.0.2.2 to reach host machine.
    return "http://10.0.2.2:$_backendPort";
  }

  // ✅ ONLY change: simple check so missing '@' doesn't trigger long backend 422 error
  bool _looksLikeEmail(String email) {
    // requires something@something.something
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onLogin() async {
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    // ✅ ONLY change: nicer message when '@' is missing
    if (!_looksLikeEmail(email)) {
      showAuthError(
          context, "Please enter a valid email (example: name@gmail.com).");
      return;
    }

    setState(() => _loading = true);

    try {
      final uri = Uri.parse("${_baseUrl()}/auth/login");

      final res = await http.post(
        uri,
        headers: const {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (!mounted) return;
        final userId = (data["user_id"] as num).toInt();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MatchingResultsScreen(userId: userId),
          ),
        );
        return;
      }

      final detail =
          (data["detail"] ?? data["message"] ?? "").toString().trim();
      showAuthError(
        context,
        detail.isNotEmpty
            ? detail
            : "Login failed. Please check your credentials.",
      );
    } catch (_) {
      showAuthError(context, "Server error. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: "Welcome back",
      subtitle: "Login to continue your learning journey.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _dec("Email", Icons.email_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: _dec(
              "Password",
              Icons.lock_outline,
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility : Icons.visibility_off,
                  color: FluentzColors.navy.withOpacity(0.7),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen()),
                );
              },
              child: const Text(
                "Forgot password?",
                style: TextStyle(
                  color: FluentzColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: _loading ? null : _onLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: FluentzColors.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    "Login",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: FluentzColors.navy,
              side: BorderSide(color: FluentzColors.navy.withOpacity(0.18)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              "Create an account",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
