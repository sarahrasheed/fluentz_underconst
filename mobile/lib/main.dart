import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() => runApp(const FluentzApp());

class FluentzApp extends StatelessWidget {
  const FluentzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}