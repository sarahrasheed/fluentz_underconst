import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    await _storage.write(key: "auth_token", value: token);
    await _storage.write(key: "user_json", value: jsonEncode(user));
  }

  static Future<void> clear() async {
    await _storage.delete(key: "auth_token");
    await _storage.delete(key: "user_json");
  }

  static Future<String?> getToken() => _storage.read(key: "auth_token");
}