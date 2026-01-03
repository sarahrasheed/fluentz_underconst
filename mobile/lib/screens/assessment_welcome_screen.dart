import 'package:flutter/material.dart';
import '../theme/fluentz_colors.dart';
import 'ai_assessment_screen.dart';

class AssessmentWelcomeScreen extends StatelessWidget {
  const AssessmentWelcomeScreen({
    super.key,
    required this.userId,
    required this.languageId,
    required this.languageName,
  });

  final int userId;
  final int languageId;
  final String languageName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FluentzColors.lightYellow,
      appBar: AppBar(
        backgroundColor: FluentzColors.lightYellow,
        elevation: 0,
        foregroundColor: FluentzColors.navy,
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              "Welcome to Fluentz 👋",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: FluentzColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Before you start, take a short placement test so we can set your level accurately.",
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: FluentzColors.navy.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FluentzColors.navy.withOpacity(0.10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.language, color: FluentzColors.navy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Assessment language: $languageName",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: FluentzColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FluentzColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiAssessmentScreen(
                        userId: userId,
                        languageId: languageId,
                        languageName: languageName,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "Start assessment",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
