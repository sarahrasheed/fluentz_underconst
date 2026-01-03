import 'package:flutter/material.dart';
import '../theme/fluentz_colors.dart';
import 'otp_screen.dart';
import '../widgets/auth_shell.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../widgets/auth_feedback.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
return InputDecoration(
  labelText: label,
  prefixIcon: Icon(icon, color: FluentzColors.navy.withOpacity(0.75)),
  suffixIcon: suffix,
  filled: true,
  fillColor: const Color(0xFFFCF5E6), // light yellow (your palette)
  labelStyle: TextStyle(color: FluentzColors.navy.withOpacity(0.75)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFFCCB4E), width: 2), // hot yellow
  ),
);
  }

  Future<void> _onRegister() async {
  FocusScope.of(context).unfocus();

  final name = _nameCtrl.text.trim();
  final email = _emailCtrl.text.trim();
  final pass = _passCtrl.text;
  final confirm = _confirmCtrl.text;

  if (name.isEmpty || email.isEmpty || pass.isEmpty || confirm.isEmpty) {
    showAuthError(context, "Please fill in all fields.");
    return;
  }

  if (!email.contains("@") || !email.contains(".")) {
    showAuthError(context, "Please enter a valid email (example: name@gmail.com).");
    return;
  }

  if (pass != confirm) {
    showAuthError(context, "Passwords do not match.");
    return;
  }

  setState(() => _loading = true);

  try {
    final baseUrl = (kIsWeb) ? "http://127.0.0.1:8000" : "http://10.0.2.2:8000";
    final url = Uri.parse("$baseUrl/auth/register");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "full_name": name,
        "email": email,
        "password": pass,
      }),
    );

    if (!mounted) return;

    if (res.statusCode == 200 || res.statusCode == 201) {
      // ✅ user created + otp generated
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created. OTP sent.")),
      );

      // NEXT STEP: go to OTP screen (we’ll build it next)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpScreen(email: email)),
      );
      return;
    }

    // readable errors
    String msg = "Registration failed. Please try again.";
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body["detail"] != null) {
        msg = body["detail"].toString();
      }
    } catch (_) {}
    showAuthError(context, msg);

  } catch (_) {
    if (!mounted) return;
    showAuthError(context, "Cannot reach server. Make sure backend is running.");
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

@override
Widget build(BuildContext context) {
  return AuthShell(
    title: "Create account",
    subtitle: "Join Fluentz and start learning through real conversations.",
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameCtrl,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: _inputDecoration(
            label: "Full name",
            icon: Icons.person_outline,
          ),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: _inputDecoration(
            label: "Email",
            icon: Icons.email_outlined,
          ),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          decoration: _inputDecoration(
            label: "Password",
            icon: Icons.lock_outline,
            suffix: IconButton(
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
              icon: Icon(
                _obscurePass ? Icons.visibility : Icons.visibility_off,
                color: FluentzColors.navy.withOpacity(0.75),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _confirmCtrl,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          decoration: _inputDecoration(
            label: "Confirm password",
            icon: Icons.lock_outline,
            suffix: IconButton(
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                color: FluentzColors.navy.withOpacity(0.75),
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        ElevatedButton(
          onPressed: _loading ? null : _onRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: FluentzColors.navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size.fromHeight(52),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  "Create account",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),

        const SizedBox(height: 12),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Already have an account? Login",
            style: TextStyle(
              color: FluentzColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}
}