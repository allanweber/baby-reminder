import 'dart:async';
import 'dart:io' show Platform;

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'alarm_service.dart';
import 'error_log.dart';
import 'ring_policy.dart';

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

  /// Arms the alarm shared by the real reminder, the per-reminder care alarms
  /// and the diagnostic test, so a passing test genuinely exercises the same
  /// sound / vibration / lock-screen delivery a feed reminder uses.
  ///
  /// The phone's mute / Do Not Disturb state is applied here and re-applied
  /// natively just before the alarm rings (see [RingPolicyBridge]): Android's
  /// alarm stream ignores both, so the app has to honour them itself, and a
  /// reminder armed after a feed is usually hours old by the time it goes off.
  Future<void> _armAlarm({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String soundId,
  }) async {
    final soundAsset = 'assets/sounds/${resolveAlarmSoundId(soundId)}.wav';
    final policy = await RingPolicyBridge.current();

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: id,
        dateTime: at,
        // Muting swaps in a silent track rather than turning a volume down, so
        // the alarm still takes over the screen and the device's own alarm
        // volume is never touched.
        assetAudioPath:
            policy.isAudible ? soundAsset : RingPolicyBridge.silentAsset,
        loopAudio: true,
        vibrate: policy.vibrates,
        // Don't warn on kill: alarms are scheduled through Android's
        // AlarmManager and still fire with the app closed, so the "reopen so
        // alarms can ring" notification was misleading (and showed up even when
        // nothing was armed).
        warningNotificationOnKill: false,
        // Take over the whole screen like the OS alarm clock — this is what
        // surfaces it over the lock screen and keeps it up until the user
        // dismisses it or adds more time.
        androidFullScreenIntent: true,
        // Ring at the device's current alarm-stream volume instead of forcing a
        // fixed level. Passing no volume (the default) means the `alarm` package
        // does not override the system volume, so the alarm honours the phone's
        // alarm volume rather than blasting at a hard-coded one.
        volumeSettings: const VolumeSettings.fixed(),
        notificationSettings: NotificationSettings(
          title: title,
          body: body,
          stopButton: 'Stop',
          icon: 'ic_stat_bottle',
          iconColor: const Color(0xFFE39C8B),
        ),
      ),
    );

    // Hand the *intended* sound to the native guard, not the one just armed:
    // that is what lets it restore full volume if the phone is unmuted before
    // the alarm is due, as well as silence it if it is muted after this point.
    await RingPolicyBridge.arm(
      id: id,
      at: at,
      assetAudioPath: soundAsset,
      vibrate: true,
    );
  }

  Future<void> scheduleReminder(
    DateTime at, {
    required String babyName,
    required String soundId,
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
    await _armAlarm(
      id: _reminderAlarmId,
      at: fireAt,
      title: resolvedTitle,
      body: resolvedBody,
      soundId: soundId,
    );
    await ErrorLog.breadcrumb('schedule: reminder set OK');
  }

  /// Arms an arbitrary alarm [id] at [at], using the exact same full-screen /
  /// sound / vibration delivery as the feed reminder. Used for the per-reminder
  /// care alarms (medicine, vitamins…), each of which owns its own [id] so they
  /// can be armed, re-armed and cancelled independently. An [at] in the past
  /// fires almost immediately (an overdue reminder still rings on app open).
  Future<void> scheduleAlarmAt({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String soundId,
  }) async {
    if (_inFlutterTest) return;
    await init();
    await Alarm.stop(id);
    final now = DateTime.now();
    final fireAt = at.isAfter(now) ? at : now.add(const Duration(seconds: 2));
    await _armAlarm(
      id: id,
      at: fireAt,
      title: title,
      body: body,
      soundId: soundId,
    );
  }

  /// Cancels a previously armed alarm by [id] (feed reminder, test, or any
  /// per-reminder care alarm).
  Future<void> cancelAlarm(int id) async {
    if (_inFlutterTest) return;
    await Alarm.stop(id);
    await RingPolicyBridge.cancel(id);
  }

  /// Schedules a one-off diagnostic alarm [delay] from now, using the exact
  /// same delivery path as a real feed reminder. Lets the user verify on their
  /// own device that a closed/locked-phone alarm actually fires.
  Future<void> scheduleTest({
    Duration delay = const Duration(seconds: 10),
    required String soundId,
  }) async {
    if (_inFlutterTest) return;
    await init();
    await Alarm.stop(_testAlarmId);
    await ErrorLog.breadcrumb('test: Alarm.set');
    await _armAlarm(
      id: _testAlarmId,
      at: DateTime.now().add(delay),
      title: 'Test alarm',
      body: 'If you can see and hear this with the app closed, real reminders will work too.',
      soundId: soundId,
    );
    await ErrorLog.breadcrumb('test: set OK');
  }

  Future<void> cancelReminder() async {
    if (_inFlutterTest) return;
    await Alarm.stop(_reminderAlarmId);
    await RingPolicyBridge.cancel(_reminderAlarmId);
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
