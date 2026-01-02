import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/fluentz_colors.dart';

class OtpScreen extends StatefulWidget {
  final String email; // we’ll pass it from Register later

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text.trim()).join();

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // If user pasted multiple chars, keep only last char
      _ctrls[index].text = value.substring(value.length - 1);
      _ctrls[index].selection = TextSelection.fromPosition(
        const TextPosition(offset: 1),
      );
    }

    if (value.isNotEmpty && index < 5) {
      _nodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      // backspace behavior: go back
      // (user can tap too)
    }
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();

    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the 6-digit code")),
      );
      return;
    }

    setState(() => _loading = true);

    // TODO: connect to backend verify endpoint later
    await Future.delayed(const Duration(milliseconds: 900));

 if (!mounted) return;
setState(() => _loading = false);

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => OtpScreen(email: email),
  ),
);

    // TODO: Navigate to Assessment Intro next step
  }

  void _resend() {
    if (_secondsLeft > 0) return;

    // TODO: call backend resend OTP later
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("OTP resent (UI only)")),
    );
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 46,
      height: 54,
      child: TextField(
        controller: _ctrls[i],
        focusNode: _nodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: FluentzColors.navy,
        ),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => _onChanged(i, v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FluentzColors.lightYellow,
      appBar: AppBar(
        backgroundColor: FluentzColors.lightYellow,
        elevation: 0,
        foregroundColor: FluentzColors.navy,
        title: const Text(
          "Verify email",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),

                Text(
                  "We sent a 6-digit code to:",
                  style: TextStyle(
                    fontSize: 15,
                    color: FluentzColors.navy.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: FluentzColors.navy,
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, _otpBox),
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FluentzColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                          "Verify",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),

                const SizedBox(height: 14),

                TextButton(
                  onPressed: _secondsLeft == 0 ? _resend : null,
                  child: Text(
                    _secondsLeft == 0
                        ? "Resend code"
                        : "Resend in $_secondsLeft s",
                    style: const TextStyle(
                      color: FluentzColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}