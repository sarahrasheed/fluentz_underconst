import 'package:flutter/material.dart';
import '../theme/fluentz_colors.dart';

class AuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? bottom;

  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = (size.height * 0.07).clamp(20.0, 60.0);

    return Scaffold(
      backgroundColor: FluentzColors.lightYellow,
      body: SafeArea(
        child: Stack(
          children: [
            // Soft background blobs
            Positioned(
              top: -80,
              right: -90,
              child: _Blob(size: 220, color: FluentzColors.purple.withOpacity(0.20)),
            ),
            Positioned(
              top: 140,
              left: -110,
              child: _Blob(size: 240, color: FluentzColors.lightBlue.withOpacity(0.18)),
            ),
            Positioned(
              bottom: -110,
              right: -120,
              child: _Blob(size: 280, color: FluentzColors.pink.withOpacity(0.14)),
            ),

            // Content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Column(
                  children: [
                    SizedBox(height: topPad),

                    // Logo
                    Image.asset(
                      'assets/images/fluentz_logo.png',
                      width: 82,
                      height: 82,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 14),

                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: FluentzColors.navy,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: FluentzColors.navy.withOpacity(0.70),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.96),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: FluentzColors.navy.withOpacity(0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: child,
                    ),

                    if (bottom != null) ...[
                      const SizedBox(height: 12),
                      bottom!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}