import 'package:flutter/material.dart';
import '../theme/fluentz_colors.dart';

void showAuthError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: FluentzColors.pink.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FluentzColors.pink.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: FluentzColors.pink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: FluentzColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
