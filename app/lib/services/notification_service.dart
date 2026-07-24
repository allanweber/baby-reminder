import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'alarm_service.dart';

/// Action id for the "Stop" button on the alarm notification.
const _dismissAlarmActionId = 'dismiss_alarm';

/// Handles a tap on the notification's "Stop" action — including from the lock
/// screen and when the app process is dead. The action itself cancels the
/// notification (which stops the insistent alarm sound); here we also persist
/// the dismissed flag so the app doesn't immediately re-ring when next opened.
/// Runs in its own isolate, so it can only touch SharedPreferences directly.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  if (response.actionId == _dismissAlarmActionId) {
    final prefs = await SharedPreferences.getInstance();
    // Keys must match StorageService. Mark the feed reminder dismissed and
    // clear any custom timer, so neither re-rings when the app is next opened.
    await prefs.setBool('reminderDismissed', true);
    await prefs.remove('customTimerAt');
  }
}

/// Schedules the "next feed" reminder as a real OS-level local notification
/// that behaves like an alarm clock: it uses a full-screen intent, the alarm
/// audio stream and the insistent flag, so the chosen sound loops until the
/// user dismisses it. This is the fallback for when the app isn't open; the
/// in-app [AlarmService] handles the case where it is.
class NotificationService {
  static const _reminderNotificationId = 1;
  static const _testNotificationId = 2;

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
      onDidReceiveNotificationResponse: notificationTapBackground,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
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

  /// Builds the alarm-clock notification details shared by the real reminder
  /// and the diagnostic test, so a passing test genuinely exercises the same
  /// full-screen / insistent / lock-screen config the feed reminder uses.
  AndroidNotificationDetails _alarmAndroidDetails(String id) {
    return AndroidNotificationDetails(
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
      // Show on the lock screen so the "Stop" action is reachable there.
      visibility: NotificationVisibility.public,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          _dismissAlarmActionId,
          'Stop',
          cancelNotification: true,
          showsUserInterface: false,
        ),
      ],
    );
  }

  /// Schedules the alarm at [at] as an OS-level notification that survives the
  /// app being closed. Prefers [AndroidScheduleMode.alarmClock] (AlarmManager's
  /// setAlarmClock — Doze-proof, lock-screen, status-bar alarm icon), but that
  /// requires the exact-alarm permission on Android 12+; if it's not granted
  /// the plugin throws. Rather than swallow that and schedule nothing (the bug
  /// that made alarms only ring while the app was open), fall back to an
  /// inexact-while-idle alarm, which needs no permission and still fires with
  /// the app closed — just not to the exact second.
  Future<void> _scheduleAlarm({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String soundId,
  }) async {
    final when = tz.TZDateTime.from(at, tz.local);
    final details = NotificationDetails(
      android: _alarmAndroidDetails(soundId),
      iOS: DarwinNotificationDetails(
        sound: '$soundId.wav',
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
    try {
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> scheduleReminder(
    DateTime at, {
    required String babyName,
    required String soundId,
    String? title,
    String? body,
  }) async {
    await init();
    await _plugin.cancel(_reminderNotificationId);
    if (at.isBefore(DateTime.now())) return;

    final id = resolveAlarmSoundId(soundId);
    final resolvedTitle = title ?? (babyName.isNotEmpty ? "$babyName's next feed" : 'Feed reminder');
    final resolvedBody = body ?? "It's about time for the next feed.";

    await _scheduleAlarm(
      notificationId: _reminderNotificationId,
      title: resolvedTitle,
      body: resolvedBody,
      at: at,
      soundId: id,
    );
  }

  /// Schedules a one-off diagnostic alarm [delay] from now, using the exact
  /// same delivery path as a real feed reminder. Lets the user verify on their
  /// own device that a closed/locked-phone alarm actually fires — the one thing
  /// that can't be checked without hardware.
  Future<void> scheduleTest({
    Duration delay = const Duration(seconds: 10),
    required String soundId,
  }) async {
    await init();
    await _scheduleAlarm(
      notificationId: _testNotificationId,
      title: 'Test alarm',
      body: 'If you can see and hear this with the app closed, real reminders will work too.',
      at: DateTime.now().add(delay),
      soundId: resolveAlarmSoundId(soundId),
    );
  }

  Future<void> cancelReminder() async {
    await _plugin.cancel(_reminderNotificationId);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Whether the OS will actually display notifications this app posts. If this
  /// is false, alarms fire but nothing is shown — the classic "only rings when
  /// the app is open" symptom (the in-app sound works, the notification is
  /// suppressed).
  Future<bool> notificationsEnabled() async {
    await init();
    return (await _android?.areNotificationsEnabled()) ?? true;
  }

  /// Whether the app is allowed to schedule exact alarms ("Alarms & reminders"
  /// on Android 12+). Without it, scheduled alarms are delayed or dropped in
  /// Doze, so they don't fire reliably while the phone is idle/locked.
  Future<bool> exactAlarmsAllowed() async {
    await init();
    return (await _android?.canScheduleExactNotifications()) ?? true;
  }

  /// Prompts for the runtime notifications permission (Android 13+). Returns
  /// whether it ended up granted.
  Future<bool> requestNotifications() async {
    await init();
    return (await _android?.requestNotificationsPermission()) ?? false;
  }

  /// Opens the system "Alarms & reminders" screen so the user can allow exact
  /// alarms. Returns whether it is granted afterwards.
  Future<bool> requestExactAlarms() async {
    await init();
    return (await _android?.requestExactAlarmsPermission()) ?? false;
  }
}
