import 'package:shared_preferences/shared_preferences.dart';

/// Persists the most recent uncaught error to disk so it can be shown in-app.
/// On a real device with no debugger attached this is the only practical way to
/// see *why* something crashed — the app records the error, and the Settings
/// diagnostics panel reads it back on the next launch.
class ErrorLog {
  static const _key = 'lastError';
  static const _crumbKey = 'lastStep';

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

  /// Records the step the app is *about to* perform, flushed to disk before
  /// that step runs. A native crash (below the Dart layer) records no error of
  /// its own, but this last breadcrumb survives — so reopening the app reveals
  /// exactly which call died. `await` this before the risky call so the write
  /// is committed first.
  static Future<void> breadcrumb(String step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = DateTime.now().toIso8601String().substring(11, 19);
      await prefs.setString(_crumbKey, '[$ts] $step');
    } catch (_) {}
  }

  static Future<String?> readBreadcrumb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_crumbKey);
    } catch (_) {
      return null;
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
      await prefs.remove(_crumbKey);
    } catch (_) {}
  }
}
