class AppConfig {
  // Android emulator talking to your Mac:
  // If your backend runs on your Mac at port 8000, Android emulator must use 10.0.2.2
  static const String baseUrlAndroidEmu = "http://10.0.2.2:8000";

  // If running on Chrome:
  static const String baseUrlWeb = "http://127.0.0.1:8000";
}