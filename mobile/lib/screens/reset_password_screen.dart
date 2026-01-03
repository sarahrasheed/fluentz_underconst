import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/fluentz_colors.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_feedback.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});
  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  static const int _backendPort = 8000;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String _baseUrl() {
    if (kIsWeb) return "http://127.0.0.1:$_backendPort";
    return "http://10.0.2.2:$_backendPort";
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();

    final otp = _otpCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (otp.isEmpty || pass.isEmpty || confirm.isEmpty) {
      showAuthError(context, "Please fill all fields.");
      return;
    }
    if (pass != confirm) {
      showAuthError(context, "Passwords do not match.");
      return;
    }

    setState(() => _loading = true);

    try {
      final uri = Uri.parse("${_baseUrl()}/auth/reset-password");
      final res = await http.post(
        uri,
        headers: const {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
          "otp": otp,
          "new_password": pass,
        }),
      );

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password updated. Please login.")),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
        return;
      }

      final detail =
          (data["detail"] ?? data["message"] ?? "").toString().trim();
      showAuthError(
          context, detail.isNotEmpty ? detail : "Reset failed. Try again.");
    } catch (_) {
      showAuthError(context, "Server error. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: "Reset password",
      subtitle: "Enter the OTP sent to ${widget.email}.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "OTP Code",
              filled: true,
              fillColor: const Color(0xFFFBFBFC),
              prefixIcon: Icon(Icons.verified_outlined,
                  color: FluentzColors.navy.withOpacity(0.75)),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure1,
            decoration: InputDecoration(
              labelText: "New password",
              filled: true,
              fillColor: const Color(0xFFFBFBFC),
              prefixIcon: Icon(Icons.lock_outline,
                  color: FluentzColors.navy.withOpacity(0.75)),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure1 = !_obscure1),
                icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscure2,
            decoration: InputDecoration(
              labelText: "Confirm password",
              filled: true,
              fillColor: const Color(0xFFFBFBFC),
              prefixIcon: Icon(Icons.lock_outline,
                  color: FluentzColors.navy.withOpacity(0.75)),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure2 = !_obscure2),
                icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _loading ? null : _reset,
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
                : const Text("Update password",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
