import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'profile_setup_screen.dart';
import '../theme/fluentz_colors.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_feedback.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.email});
  final String email;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpCtrl = TextEditingController();
  bool _loading = false;

  static const int _backendPort = 8000;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  String _baseUrl() {
    if (kIsWeb) return "http://127.0.0.1:$_backendPort";
    return "http://10.0.2.2:$_backendPort"; // android emulator -> host
  }

  String _extractFastApiDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded["detail"] != null) {
        final detail = decoded["detail"];
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first["msg"] != null) {
            return first["msg"].toString();
          }
          return detail.toString();
        }
        return detail.toString();
      }
    } catch (_) {}
    return "Invalid OTP. Please try again.";
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();

    final email = widget.email.trim();
    final otp = _otpCtrl.text.trim();

    if (email.isEmpty) {
      showAuthError(context, "Missing email. Please register again.");
      return;
    }

    if (otp.isEmpty) {
      showAuthError(context, "Please enter the OTP code.");
      return;
    }

    // Optional: keep OTP clean (digits only)
    final digitsOnly = RegExp(r'^\d{4,8}$'); // adjust length if you want
    if (!digitsOnly.hasMatch(otp)) {
      showAuthError(context, "OTP must be numbers only.");
      return;
    }

    setState(() => _loading = true);

    try {
      final url = Uri.parse("${_baseUrl()}/auth/verify-otp");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "otp": otp, // ✅ string exactly like your backend example
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        // Backend may return:
        // {"message":"Email verified","user_id":5,"next_step":"profile_setup"}
        // OR {"message":"Already verified","user_id":5,"next_step":"profile_setup"}
        int? userId;
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body["user_id"] != null) {
            userId = (body["user_id"] as num).toInt();
          }
        } catch (_) {}

        if (userId == null) {
          showAuthError(
              context, "Verified, but missing user_id from server response.");
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email verified ✅")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              userId: userId!,
              email: widget.email,
            ),
          ),
        );
        return;
      }

      showAuthError(context, _extractFastApiDetail(res.body));
    } catch (_) {
      if (!mounted) return;
      showAuthError(
          context, "Cannot reach server. Make sure backend is running.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: "Verify your email",
      subtitle: "We sent a code to ${widget.email}. Enter it below.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "OTP code",
              filled: true,
              fillColor: const Color(0xFFFBFBFC),
              labelStyle: TextStyle(color: FluentzColors.navy.withOpacity(0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: FluentzColors.navy.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: FluentzColors.navy.withOpacity(0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: FluentzColors.lightBlue, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _loading ? null : _verifyOtp,
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
                : const Text(
                    "Verify",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }
}
