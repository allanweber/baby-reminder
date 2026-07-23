import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the "next feed" reminder as a real OS-level local notification,
/// so it still fires when the app is backgrounded or closed. The in-app
/// countdown banner (see HomeScreen) remains the primary UI while the app is
/// open; this is the fallback for when it isn't.
class NotificationService {
  static const _channelId = 'feed_reminders';
  static const _channelName = 'Feed reminders';
  static const _channelDescription = 'Reminds you when it is time for the next feed.';
  static const _reminderNotificationId = 1;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {
      // Fall back to UTC if the platform can't resolve the local timezone.
    }

    // A flat white silhouette, not the full-color launcher icon: Android's
    // status bar renders small icons as a plain mask, so a colorful icon
    // just shows up as a solid blob.
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_bottle');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> scheduleReminder(DateTime at, {required String babyName}) async {
    await init();
    await _plugin.cancel(_reminderNotificationId);
    if (at.isBefore(DateTime.now())) return;

    final title = babyName.isNotEmpty ? "$babyName's next feed" : 'Feed reminder';
    await _plugin.zonedSchedule(
      _reminderNotificationId,
      title,
      "It's about time for the next feed.",
      tz.TZDateTime.from(at, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFFE39C8B),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder() async {
    await _plugin.cancel(_reminderNotificationId);
  }
}
