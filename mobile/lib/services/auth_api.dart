import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

class AuthApi {
  static String get _baseUrl {
    if (kIsWeb) return AppConfig.baseUrlWeb;
    return AppConfig.baseUrlAndroidEmu;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse("$_baseUrl/auth/login");

    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    // Success
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    // Error: try to read FastAPI detail
    try {
      final body = jsonDecode(res.body);
      final detail = body["detail"];
      throw AuthException(detail?.toString() ?? "Login failed");
    } catch (_) {
      throw AuthException("Login failed (${res.statusCode})");
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}