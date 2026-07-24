import 'dart:async';
import 'dart:io' show Platform;

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'alarm_service.dart';
import 'error_log.dart';

/// Schedules the "next feed" reminder as a real OS alarm using the `alarm`
/// package, which rings with sound + vibration and posts a lock-screen
/// notification even when the app is closed or the process has been killed —
/// backed by a foreground service and AlarmManager, so it doesn't depend on the
/// app being open. The looping in-app [AlarmService] still handles the case
/// where the app happens to be in the foreground when the reminder comes due
/// (the running app cancels the scheduled OS alarm and takes over — see
/// [AppState._evaluateAlarm]).
///
/// `flutter_local_notifications` is kept only to drive the permission
/// diagnostics in Settings (checking / requesting the notification and
/// exact-alarm permissions); it no longer schedules anything.
class NotificationService {
  /// Shared by the feed reminder and the custom timer (only ever one of them is
  /// armed at a time). Exposed so [AppState] can tell whether the currently
  /// ringing alarm is ours.
  static const reminderAlarmId = 1;
  static const _reminderAlarmId = reminderAlarmId;
  static const _testAlarmId = 2;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  StreamSubscription<dynamic>? _ringingSub;

  // Under `flutter test` there are no platform channels: the alarm plugin's
  // pigeon calls block forever waiting for a native reply that never arrives
  // (and hang the widget test's fake-async clock). Skip all native work in
  // that environment so the pure state logic stays testable.
  static final bool _inFlutterTest =
      Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> init() async {
    if (_initialized) return;
    if (_inFlutterTest) {
      _initialized = true;
      return;
    }

    await ErrorLog.breadcrumb('init: Alarm.init');
    // Guarded so a platform failure (e.g. under `flutter test`, where plugin
    // channels are absent) can't propagate; on a real device this succeeds and
    // is what makes the closed-app alarm work.
    try {
      await Alarm.init();
    } catch (_) {}

    // Initialise flutter_local_notifications purely so its permission APIs
    // (used by the Settings diagnostics) are available. No scheduling, no
    // channels, no custom sounds — none of the config that used to crash the
    // notification post on this device.
    await ErrorLog.breadcrumb('init: local-notif (permissions only)');
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_bottle');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );
    } catch (_) {}

    // Requesting permissions launches system UI/intents that can throw on some
    // devices; this runs at startup, so guard each one.
    await ErrorLog.breadcrumb('init: request notifications permission');
    try {
      await _android?.requestNotificationsPermission();
    } catch (_) {}
    await ErrorLog.breadcrumb('init: request exact-alarms permission');
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}

    await ErrorLog.breadcrumb('init: done');
    _initialized = true;
  }

  /// Subscribes to the native alarm's ringing state and reports the set of
  /// currently ringing alarm ids. This is the single source of truth for
  /// whether an alarm is sounding — the same whether the app is in the
  /// foreground, was launched by the alarm's full-screen intent over the lock
  /// screen, or is resumed while an alarm is still looping. No-ops in tests.
  void onRinging(void Function(Set<int> ringingIds) callback) {
    if (_inFlutterTest) return;
    _ringingSub?.cancel();
    _ringingSub = Alarm.ringing.listen((alarmSet) {
      callback(alarmSet.alarms.map((a) => a.id).toSet());
    });
  }

  Future<void> dispose() async {
    await _ringingSub?.cancel();
    _ringingSub = null;
  }

  /// Builds the alarm shared by the real reminder and the diagnostic test, so a
  /// passing test genuinely exercises the same sound / vibration / lock-screen
  /// delivery the feed reminder uses.
  AlarmSettings _buildAlarm({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String soundId,
    required double volume,
  }) {
    return AlarmSettings(
      id: id,
      dateTime: at,
      assetAudioPath: 'assets/sounds/${resolveAlarmSoundId(soundId)}.wav',
      loopAudio: true,
      vibrate: true,
      // Warn the user if Android kills the alarm's foreground service, so a
      // due feed can't silently disappear.
      warningNotificationOnKill: true,
      // Take over the whole screen like the OS alarm clock — this is what
      // surfaces it over the lock screen and keeps it up until the user
      // dismisses it or adds more time.
      androidFullScreenIntent: true,
      volumeSettings: VolumeSettings.fixed(volume: volume.clamp(0.0, 1.0)),
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'Stop',
        icon: 'ic_stat_bottle',
        iconColor: const Color(0xFFE39C8B),
      ),
    );
  }

  Future<void> scheduleReminder(
    DateTime at, {
    required String babyName,
    required String soundId,
    required double volume,
    String? title,
    String? body,
  }) async {
    if (_inFlutterTest) return;
    await init();
    await Alarm.stop(_reminderAlarmId);
    // A time in the past can't be scheduled directly. When the reminder is
    // already overdue (e.g. the app was closed past the due time and is now
    // reopening), fire almost immediately so it still rings through the real
    // alarm engine — full screen, sound and vibration — instead of silently
    // doing nothing.
    final now = DateTime.now();
    final fireAt = at.isAfter(now) ? at : now.add(const Duration(seconds: 2));

    final resolvedTitle =
        title ?? (babyName.isNotEmpty ? "$babyName's next feed" : 'Feed reminder');
    final resolvedBody = body ?? "It's about time for the next feed.";

    await ErrorLog.breadcrumb('schedule: Alarm.set reminder');
    await Alarm.set(
      alarmSettings: _buildAlarm(
        id: _reminderAlarmId,
        at: fireAt,
        title: resolvedTitle,
        body: resolvedBody,
        soundId: soundId,
        volume: volume,
      ),
    );
    await ErrorLog.breadcrumb('schedule: reminder set OK');
  }

  /// Schedules a one-off diagnostic alarm [delay] from now, using the exact
  /// same delivery path as a real feed reminder. Lets the user verify on their
  /// own device that a closed/locked-phone alarm actually fires.
  Future<void> scheduleTest({
    Duration delay = const Duration(seconds: 10),
    required String soundId,
    required double volume,
  }) async {
    if (_inFlutterTest) return;
    await init();
    await Alarm.stop(_testAlarmId);
    await ErrorLog.breadcrumb('test: Alarm.set');
    await Alarm.set(
      alarmSettings: _buildAlarm(
        id: _testAlarmId,
        at: DateTime.now().add(delay),
        title: 'Test alarm',
        body: 'If you can see and hear this with the app closed, real reminders will work too.',
        soundId: soundId,
        volume: volume,
      ),
    );
    await ErrorLog.breadcrumb('test: set OK');
  }

  Future<void> cancelReminder() async {
    if (_inFlutterTest) return;
    await Alarm.stop(_reminderAlarmId);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Whether the OS will actually display notifications this app posts. If this
  /// is false, alarms may fire but nothing is shown.
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
