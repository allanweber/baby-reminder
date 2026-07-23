import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'alarm_service.dart';

/// Schedules the "next feed" reminder as a real OS-level local notification
/// that behaves like an alarm clock: it uses a full-screen intent, the alarm
/// audio stream and the insistent flag, so the chosen sound loops until the
/// user dismisses it. This is the fallback for when the app isn't open; the
/// in-app [AlarmService] handles the case where it is.
class NotificationService {
  static const _reminderNotificationId = 1;

  // FLAG_INSISTENT (0x4): Android keeps replaying the notification sound until
  // the notification is cancelled/dismissed — i.e. it rings like an alarm.
  static final _insistentFlags = Int32List.fromList(<int>[4]);

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  String _channelIdFor(String soundId) => 'feed_alarm_$soundId';

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

    // One channel per sound: on Android 8+ a channel's sound is fixed at
    // creation, so switching the alarm sound means switching channels. Each is
    // configured to play on the alarm stream at high importance.
    for (final s in kAlarmSounds) {
      await androidImpl?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelIdFor(s.id),
          'Feed alarm — ${s.label}',
          description: 'Rings when it is time for the next feed.',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(s.id),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
        ),
      );
    }

    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> scheduleReminder(
    DateTime at, {
    required String babyName,
    required String soundId,
  }) async {
    await init();
    await _plugin.cancel(_reminderNotificationId);
    if (at.isBefore(DateTime.now())) return;

    final id = resolveAlarmSoundId(soundId);
    final title = babyName.isNotEmpty ? "$babyName's next feed" : 'Feed reminder';

    final androidDetails = AndroidNotificationDetails(
      _channelIdFor(id),
      'Feed alarm',
      channelDescription: 'Rings when it is time for the next feed.',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(id),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      additionalFlags: _insistentFlags,
      color: const Color(0xFFE39C8B),
    );

    await _plugin.zonedSchedule(
      _reminderNotificationId,
      title,
      "It's about time for the next feed.",
      tz.TZDateTime.from(at, tz.local),
      NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          sound: '$id.wav',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
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
