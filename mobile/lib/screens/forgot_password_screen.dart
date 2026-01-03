import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/fluentz_colors.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_feedback.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  static const int _backendPort = 8000;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String _baseUrl() {
    if (kIsWeb) return "http://127.0.0.1:$_backendPort";
    return "http://10.0.2.2:$_backendPort";
  }

  bool _looksLikeEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();

    if (!_looksLikeEmail(email)) {
      showAuthError(
          context, "Please enter a valid email (example: name@gmail.com).");
      return;
    }

    setState(() => _loading = true);

    try {
      final uri = Uri.parse("${_baseUrl()}/auth/forgot-password");
      final res = await http.post(
        uri,
        headers: const {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)),
        );
        return;
      }

      final detail =
          (data["detail"] ?? data["message"] ?? "").toString().trim();
      showAuthError(context,
          detail.isNotEmpty ? detail : "Could not send OTP. Try again.");
    } catch (_) {
      showAuthError(context, "Server error. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: "Forgot password",
      subtitle: "Enter your email and we’ll send you an OTP code.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: "Email",
              filled: true,
              fillColor: const Color(0xFFFBFBFC),
              labelStyle: TextStyle(color: FluentzColors.navy.withOpacity(0.7)),
              prefixIcon: Icon(Icons.email_outlined,
                  color: FluentzColors.navy.withOpacity(0.75)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: FluentzColors.navy.withOpacity(0.08)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _loading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: FluentzColors.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text("Send OTP",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
