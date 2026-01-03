import 'package:flutter/material.dart';
import '../theme/fluentz_colors.dart';
import '../services/session_store.dart';

class AfterLoginScreen extends StatelessWidget {
  const AfterLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FluentzColors.lightYellow,
      appBar: AppBar(
        backgroundColor: FluentzColors.lightYellow,
        elevation: 0,
        title: const Text("Logged in", style: TextStyle(color: FluentzColors.navy)),
        iconTheme: const IconThemeData(color: FluentzColors.navy),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "✅ Login Success",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: FluentzColors.navy),
            ),
            const SizedBox(height: 12),
            Text(
              "Home page comes later.",
              style: TextStyle(color: FluentzColors.navy.withOpacity(0.75)),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () async {
                await SessionStore.clear();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Logout (temporary)"),
            )
          ],
        ),
      ),
    );
  }
}