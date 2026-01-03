import 'package:flutter/material.dart';
import '../theme/fluentz_colors.dart';

class WelcomeAssessmentScreen extends StatelessWidget {
  const WelcomeAssessmentScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  final int userId;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FluentzColors.lightYellow,
      appBar: AppBar(
        backgroundColor: FluentzColors.lightYellow,
        elevation: 0,
        foregroundColor: FluentzColors.navy,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: FluentzColors.navy.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Welcome to Fluentz 🎉",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: FluentzColors.navy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Your profile is set up.\nNext, take a short placement test so we can personalize your learning path.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: FluentzColors.navy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "It’s quick, text-only, and helps us pick the right level for you.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: FluentzColors.navy.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  // TODO (next step): start the AI assessment
                  // Navigator.push(... AssessmentStartScreen(userId: userId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Assessment page comes next ✅")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FluentzColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  "Start placement test",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Skip for now (we’ll handle later)")),
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
                  "Skip for now",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              const Spacer(),
              Text(
                "Signed in as: $email",
                textAlign: TextAlign.center,
                style: TextStyle(color: FluentzColors.navy.withOpacity(0.6)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
