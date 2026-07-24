import 'package:shared_preferences/shared_preferences.dart';

/// Persists the most recent uncaught error to disk so it can be shown in-app.
/// On a real device with no debugger attached this is the only practical way to
/// see *why* something crashed — the app records the error, and the Settings
/// diagnostics panel reads it back on the next launch.
class ErrorLog {
  static const _key = 'lastError';

  /// Fire-and-forget: never throws, so it is safe to call from error handlers.
  static Future<void> record(Object error, StackTrace? stack) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = DateTime.now().toIso8601String();
      final head =
          (stack?.toString() ?? '').split('\n').take(6).join('\n');
      await prefs.setString(_key, '[$ts]\n$error\n$head');
    } catch (_) {
      // Recording a crash must never itself crash.
    }
  }

  static Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
