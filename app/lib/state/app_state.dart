import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/feed.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

const mlPerOz = 29.5735;
const _uuid = Uuid();

String pad2(int n) => n < 10 ? '0$n' : '$n';
String dateStr(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';
String timeStr(DateTime d) => '${pad2(d.hour)}:${pad2(d.minute)}';
int dtToMs(String date, String time) => DateTime.parse('${date}T$time:00').millisecondsSinceEpoch;

class DayStats {
  final String totalDisplay;
  final int feedCount;
  final String avgIntervalDisplay;
  const DayStats({required this.totalDisplay, required this.feedCount, required this.avgIntervalDisplay});
}

/// Holds all persisted app state and the domain logic ported from the
/// prototype's `Component` class (feeds, reminder scheduling, settings).
/// Ephemeral UI state (which sheet is open, in-progress edits) lives in the
/// widgets themselves, not here.
class AppState extends ChangeNotifier {
  final StorageService storage;
  final NotificationService notifications;
  final AlarmService alarm;

  AppState(this.storage, this.notifications, this.alarm);

  List<Feed> feeds = [];
  String babyName = '';
  String unitPref = 'ml';
  int reminderIntervalMin = 180;
  int nextReminderAt = 0;
  bool reminderDismissed = false;
  String alarmSound = kDefaultAlarmSound;
  double alarmVolume = kDefaultAlarmVolume;
  DateTime now = DateTime.now();

  /// An on-demand countdown the user sets themselves. When active it takes over
  /// the reminder banner and the alarm in place of the feed reminder; the feed
  /// reminder is left untouched underneath and resumes once this is cancelled
  /// or dismissed. Null means no custom timer is running.
  int? customTimerAt;
  String customTimerLabel = 'Timer';

  Timer? _ticker;
  bool _alarmRinging = false;

  bool get alarmRinging => _alarmRinging;
  bool get customTimerActive => customTimerAt != null;

  /// The countdown target the UI and alarm should track right now: the custom
  /// timer when one is set, otherwise the feed reminder.
  int get effectiveReminderAt => customTimerAt ?? nextReminderAt;

  /// True when the currently ringing/pending alarm is a user timer rather than
  /// the feed reminder.
  bool get alarmIsCustomTimer => customTimerAt != null;

  Future<void> load() async {
    if (!storage.hasSeeded) {
      _seedSampleData();
      await storage.markSeeded();
      await _persistAll();
    } else {
      feeds = storage.loadFeeds();
      babyName = storage.loadBabyName() ?? '';
      unitPref = storage.loadUnitPref();
      reminderIntervalMin = storage.loadReminderIntervalMin();
      nextReminderAt = storage.loadNextReminderAt() ??
          DateTime.now().add(Duration(minutes: reminderIntervalMin)).millisecondsSinceEpoch;
      reminderDismissed = storage.loadReminderDismissed();
      alarmSound = resolveAlarmSoundId(storage.loadAlarmSound());
      alarmVolume = storage.loadAlarmVolume();
      customTimerAt = storage.loadCustomTimerAt();
      customTimerLabel = storage.loadCustomTimerLabel() ?? 'Timer';
    }
    // Tick every second so the home page — the live countdown especially —
    // stays in sync to the second, and so the alarm fires the moment the
    // reminder comes due.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      now = DateTime.now();
      _evaluateAlarm();
      notifyListeners();
    });
    _evaluateAlarm();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    alarm.dispose();
    super.dispose();
  }

  void _seedSampleData() {
    final nowDt = DateTime.now();
    final t3 = nowDt.subtract(const Duration(minutes: 40));
    final yest = nowDt.subtract(const Duration(days: 1));
    feeds = [
      Feed(id: 'y1', date: dateStr(yest), time: '07:00', type: FeedType.formula, amountMl: 110, durationMin: 0, note: ''),
      Feed(id: 'y2', date: dateStr(yest), time: '10:15', type: FeedType.breastfeeding, amountMl: 0, durationMin: 18, note: ''),
      Feed(id: 'y3', date: dateStr(yest), time: '13:30', type: FeedType.formula, amountMl: 120, durationMin: 0, note: ''),
      Feed(id: 'y4', date: dateStr(yest), time: '16:45', type: FeedType.breastBottle, amountMl: 100, durationMin: 0, note: ''),
      Feed(id: 'y5', date: dateStr(yest), time: '19:50', type: FeedType.formula, amountMl: 130, durationMin: 20, note: 'Settled quickly after'),
      Feed(id: 't1', date: dateStr(nowDt), time: '06:30', type: FeedType.formula, amountMl: 120, durationMin: 0, note: ''),
      Feed(id: 't2', date: dateStr(nowDt), time: '09:45', type: FeedType.breastBottle, amountMl: 100, durationMin: 0, note: ''),
      Feed(id: 't3', date: dateStr(t3), time: timeStr(t3), type: FeedType.formula, amountMl: 130, durationMin: 22, note: 'Fussy, took a bit longer'),
    ];
    babyName = '';
    unitPref = 'ml';
    reminderIntervalMin = 180;
    nextReminderAt = t3.add(Duration(minutes: reminderIntervalMin)).millisecondsSinceEpoch;
    reminderDismissed = false;
  }

  Future<void> _persistAll() async {
    await storage.saveFeeds(feeds);
    await storage.saveBabyName(babyName);
    await storage.saveUnitPref(unitPref);
    await storage.saveReminderIntervalMin(reminderIntervalMin);
    await storage.saveNextReminderAt(nextReminderAt);
    await storage.saveReminderDismissed(reminderDismissed);
    await storage.saveAlarmSound(alarmSound);
    await storage.saveAlarmVolume(alarmVolume);
    await storage.saveCustomTimerAt(customTimerAt);
    await storage.saveCustomTimerLabel(customTimerLabel);
  }

  /// Starts the in-app alarm the instant the reminder comes due (and keeps it
  /// going until dismissed/snoozed/logged), or stops it otherwise. When the
  /// app is open the in-app alarm is authoritative, so we also cancel the
  /// scheduled OS notification to avoid a double ring.
  void _evaluateAlarm() {
    // A running custom timer supersedes the feed reminder and is never treated
    // as "dismissed" (it is cancelled/cleared instead of dismissed).
    final shouldRing = customTimerAt != null
        ? now.millisecondsSinceEpoch >= customTimerAt!
        : now.millisecondsSinceEpoch >= nextReminderAt && !reminderDismissed;
    if (shouldRing && !_alarmRinging) {
      _alarmRinging = true;
      alarm.start(soundId: alarmSound, volume: alarmVolume);
      notifications.cancelReminder();
    } else if (!shouldRing && _alarmRinging) {
      _alarmRinging = false;
      alarm.stop();
    }
  }

  /// Scheduling can fail on-device (e.g. exact-alarm permission revoked by
  /// the OEM after install) — never let that exception stop the caller from
  /// reaching notifyListeners(), since the in-app state update must not
  /// depend on the OS notification succeeding.
  Future<void> _rescheduleNotification() async {
    try {
      if (customTimerAt != null) {
        await notifications.scheduleReminder(
          DateTime.fromMillisecondsSinceEpoch(customTimerAt!),
          babyName: babyName,
          soundId: alarmSound,
          title: customTimerLabel.isNotEmpty ? customTimerLabel : 'Timer',
          body: 'Your timer is up.',
        );
      } else if (reminderDismissed) {
        await notifications.cancelReminder();
      } else {
        await notifications.scheduleReminder(
          DateTime.fromMillisecondsSinceEpoch(nextReminderAt),
          babyName: babyName,
          soundId: alarmSound,
        );
      }
    } catch (e) {
      debugPrint('Failed to (re)schedule reminder notification: $e');
    }
  }

  String newFeedId() => 'f${_uuid.v4()}';

  /// Saves a feed (new or edited). Recomputes the reminder only for new feeds.
  Future<void> saveFeed(Feed feed, {required bool isNew}) async {
    feeds = isNew ? [...feeds, feed] : feeds.map((f) => f.id == feed.id ? feed : f).toList();
    feeds.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    // Logging a *recent* feed restarts the countdown to the next one. A feed
    // back-filled from far enough in the past that its reminder would already
    // be due (e.g. 3h+ ago with a 3h interval) is treated as history: it must
    // not start or reschedule an alarm, and it leaves any running reminder be.
    final candidate = dtToMs(feed.date, feed.time) + reminderIntervalMin * 60000;
    final startsReminder = isNew && candidate > DateTime.now().millisecondsSinceEpoch;
    if (startsReminder) {
      nextReminderAt = candidate;
      reminderDismissed = false;
    }
    await storage.saveFeeds(feeds);
    if (startsReminder) {
      await storage.saveNextReminderAt(nextReminderAt);
      await storage.saveReminderDismissed(reminderDismissed);
      _evaluateAlarm();
      await _rescheduleNotification();
    }
    notifyListeners();
  }

  Future<void> deleteFeed(String id) async {
    feeds = feeds.where((f) => f.id != id).toList();
    await storage.saveFeeds(feeds);
    notifyListeners();
  }

  Future<void> setBabyName(String name) async {
    babyName = name;
    await storage.saveBabyName(name);
    await _rescheduleNotification();
    notifyListeners();
  }

  Future<void> setUnitPref(String unit) async {
    unitPref = unit;
    await storage.saveUnitPref(unit);
    notifyListeners();
  }

  Future<void> setReminderInterval(int minutes) async {
    reminderIntervalMin = minutes;
    nextReminderAt = DateTime.now().millisecondsSinceEpoch + minutes * 60000;
    reminderDismissed = false;
    await storage.saveReminderIntervalMin(minutes);
    await storage.saveNextReminderAt(nextReminderAt);
    await storage.saveReminderDismissed(reminderDismissed);
    _evaluateAlarm();
    await _rescheduleNotification();
    notifyListeners();
  }

  Future<void> snoozeReminder() async {
    // While a custom timer is up, snoozing re-arms the timer itself for another
    // 15 minutes rather than touching the feed reminder underneath.
    if (customTimerAt != null) {
      customTimerAt = DateTime.now().millisecondsSinceEpoch;
      await extendCustomTimer(const Duration(minutes: 15));
      return;
    }
    nextReminderAt = DateTime.now().millisecondsSinceEpoch + 15 * 60000;
    reminderDismissed = false;
    await storage.saveNextReminderAt(nextReminderAt);
    await storage.saveReminderDismissed(reminderDismissed);
    _evaluateAlarm();
    await _rescheduleNotification();
    notifyListeners();
  }

  Future<void> dismissReminder() async {
    // Dismissing a ringing custom timer clears it (a one-shot), which uncovers
    // the feed reminder again. Re-evaluate so the feed reminder can take over.
    if (customTimerAt != null) {
      await cancelCustomTimer();
      return;
    }
    reminderDismissed = true;
    await storage.saveReminderDismissed(true);
    _evaluateAlarm();
    await _rescheduleNotification();
    notifyListeners();
  }

  // --- Custom on-demand timer -----------------------------------------------

  /// Starts (or replaces) a user-set countdown of [duration]. It immediately
  /// takes over the reminder banner and the alarm; any custom timer already
  /// running is replaced.
  Future<void> startCustomTimer(Duration duration, {String label = 'Timer'}) async {
    // Clearing the ringing flag lets _evaluateAlarm restart the alarm cleanly
    // if the new target is already in the past (e.g. a 0-length timer).
    if (_alarmRinging) {
      _alarmRinging = false;
      await alarm.stop();
    }
    customTimerAt = DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
    customTimerLabel = label.trim().isEmpty ? 'Timer' : label.trim();
    await storage.saveCustomTimerAt(customTimerAt);
    await storage.saveCustomTimerLabel(customTimerLabel);
    _evaluateAlarm();
    await _rescheduleNotification();
    notifyListeners();
  }

  /// Cancels the custom timer (whether counting down or ringing) and restores
  /// the feed reminder.
  Future<void> cancelCustomTimer() async {
    if (customTimerAt == null) return;
    customTimerAt = null;
    if (_alarmRinging) {
      _alarmRinging = false;
      await alarm.stop();
    }
    await storage.saveCustomTimerAt(null);
    _evaluateAlarm();
    await _rescheduleNotification();
    notifyListeners();
  }

  /// Adds [extra] to a running custom timer (used by the "+ N min" actions).
  Future<void> extendCustomTimer(Duration extra) async {
    if (customTimerAt == null) return;
    // Anchor the extension to now when the timer has already fired, so the user
    // gets the full extra time rather than an already-elapsed target.
    final base = customTimerAt! < DateTime.now().millisecondsSinceEpoch
        ? DateTime.now().millisecondsSinceEpoch
        : customTimerAt!;
    customTimerAt = base + extra.inMilliseconds;
    if (_alarmRinging) {
      _alarmRinging = false;
      await alarm.stop();
    }
    await storage.saveCustomTimerAt(customTimerAt);
    _evaluateAlarm();
    await _rescheduleNotification();
    notifyListeners();
  }

  Future<void> setAlarmSound(String id) async {
    alarmSound = resolveAlarmSoundId(id);
    await storage.saveAlarmSound(alarmSound);
    if (_alarmRinging) {
      await alarm.start(soundId: alarmSound, volume: alarmVolume);
    }
    await _rescheduleNotification();
    notifyListeners();
  }

  Future<void> setAlarmVolume(double volume) async {
    alarmVolume = volume.clamp(0.0, 1.0);
    await storage.saveAlarmVolume(alarmVolume);
    await alarm.setVolume(alarmVolume);
    notifyListeners();
  }

  /// Plays a short, non-looping preview of the given (or current) sound.
  Future<void> previewAlarm([String? id]) =>
      alarm.previewSound(soundId: id ?? alarmSound, volume: alarmVolume);

  // --- Backup & restore ------------------------------------------------------
  // All state is on-device, so an uninstall (or the one-time signing-key
  // reinstall) would otherwise wipe it. These let the user save everything to
  // a JSON file they keep, and read it back.

  static const backupVersion = 1;

  /// Serialises every feed and setting to a portable JSON string.
  String exportData() => jsonEncode({
        'app': 'baby_feed_tracker',
        'version': backupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'babyName': babyName,
        'unitPref': unitPref,
        'reminderIntervalMin': reminderIntervalMin,
        'alarmSound': alarmSound,
        'alarmVolume': alarmVolume,
        'feeds': feeds.map((f) => f.toJson()).toList(),
      });

  /// Restores from a backup produced by [exportData]. Returns the number of
  /// feeds imported, or null if the file could not be parsed.
  Future<int?> importData(String raw) async {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final rawFeeds = (data['feeds'] as List<dynamic>? ?? const []);
      final imported = rawFeeds
          .map((e) => Feed.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

      feeds = imported;
      babyName = (data['babyName'] as String?) ?? babyName;
      unitPref = (data['unitPref'] as String?) ?? unitPref;
      reminderIntervalMin = (data['reminderIntervalMin'] as int?) ?? reminderIntervalMin;
      alarmSound = resolveAlarmSoundId(data['alarmSound'] as String?);
      alarmVolume = ((data['alarmVolume'] as num?)?.toDouble() ?? alarmVolume).clamp(0.0, 1.0);

      await _persistAll();
      notifyListeners();
      return imported.length;
    } catch (e) {
      debugPrint('Failed to import backup: $e');
      return null;
    }
  }

  double mlToDisplayUnit(int ml) => unitPref == 'oz' ? ml / mlPerOz : ml.toDouble();

  String amountLabel(int ml) =>
      unitPref == 'oz' ? '${(ml / mlPerOz).toStringAsFixed(1)} oz' : '$ml ml';

  DayStats computeStats(List<Feed> list) {
    final withAmount = list.where((f) => f.amountMl > 0).toList();
    final totalMl = withAmount.fold<int>(0, (a, f) => a + f.amountMl);
    final totalDisplay = list.isEmpty ? '0 ml' : amountLabel(totalMl);
    var avgDisplay = '—';
    if (list.length >= 2) {
      final sorted = [...list]..sort((a, b) => a.sortKey.compareTo(b.sortKey));
      var gaps = 0;
      var count = 0;
      for (var i = 1; i < sorted.length; i++) {
        gaps += (dtToMs(sorted[i].date, sorted[i].time) - dtToMs(sorted[i - 1].date, sorted[i - 1].time)) ~/ 60000;
        count++;
      }
      final avgMin = (gaps / count).round();
      avgDisplay = '${avgMin ~/ 60}h ${avgMin % 60}m';
    }
    return DayStats(totalDisplay: totalDisplay, feedCount: list.length, avgIntervalDisplay: avgDisplay);
  }

  List<Feed> feedsForDate(String date) => feeds.where((f) => f.date == date).toList();
}
