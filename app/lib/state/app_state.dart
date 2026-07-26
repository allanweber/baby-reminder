import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/diaper.dart';
import '../models/feed.dart';
import '../models/reminder.dart';
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

/// A day's diaper tallies for the stats row: total changes, and how many
/// involved pee / poop (a "both" change counts toward each).
class DiaperStats {
  final int total;
  final int peeCount;
  final int poopCount;
  const DiaperStats({required this.total, required this.peeCount, required this.poopCount});
}

/// A reminder that came due on a given day but was never marked done — surfaced
/// as a grayed "Missed" row in the daily report. Only fixed-time reminders can
/// be missed (interval reminders drift, so they have no fixed clock deadline).
class MissedReminder {
  final Reminder reminder;
  final String time; // HH:MM the reminder was due at that day
  const MissedReminder(this.reminder, this.time);
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
  List<Diaper> diapers = [];
  List<Reminder> reminders = [];
  List<ReminderLog> reminderLogs = [];
  int _nextReminderAlarmId = 1000;
  String babyName = '';
  String unitPref = 'ml';
  bool darkMode = false;
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
  String? _ringingReminderId;

  bool get alarmRinging => _alarmRinging;
  bool get customTimerActive => customTimerAt != null;

  /// The reminder whose full-screen alarm is currently sounding, if any. Takes
  /// visual priority over the feed alarm in the app-wide alarm overlay.
  Reminder? get ringingReminder {
    if (_ringingReminderId == null) return null;
    for (final r in reminders) {
      if (r.id == _ringingReminderId) return r;
    }
    return null;
  }

  /// Reminders whose armed time has passed and haven't been acted on yet —
  /// these surface as "due now" cards at the top of the Reminders tab.
  List<Reminder> get dueReminders {
    final nowMs = now.millisecondsSinceEpoch;
    final due = reminders.where((r) => r.nextDueAt <= nowMs).toList()
      ..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    return due;
  }

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
      diapers = storage.loadDiapers();
      reminders = storage.loadReminders();
      reminderLogs = storage.loadReminderLogs();
      _nextReminderAlarmId = storage.loadNextReminderAlarmId();
      babyName = storage.loadBabyName() ?? '';
      unitPref = storage.loadUnitPref();
      darkMode = storage.loadDarkMode();
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
    // stays in sync to the second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      now = DateTime.now();
      notifyListeners();
    });
    // The native alarm engine is the single source of truth for whether an
    // alarm is sounding: it rings whether the app is open, closed, or was
    // launched over the lock screen by the full-screen intent. Mirror its
    // ringing state into the in-app overlay instead of running a second,
    // competing alarm here.
    notifications.onRinging((ids) {
      final feedRinging = ids.contains(NotificationService.reminderAlarmId);
      String? remId;
      for (final r in reminders) {
        if (ids.contains(r.alarmId)) {
          remId = r.id;
          break;
        }
      }
      var changed = false;
      if (feedRinging != _alarmRinging) {
        _alarmRinging = feedRinging;
        changed = true;
      }
      if (remId != _ringingReminderId) {
        _ringingReminderId = remId;
        changed = true;
      }
      if (changed) notifyListeners();
    });
    // Make sure a real OS alarm is armed for any pending reminder/timer/care
    // reminder, so they still fire when the app is later closed — previously the
    // notification was only (re)scheduled when the user changed something.
    await _rescheduleNotification();
    await _rescheduleAllReminders();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    notifications.dispose();
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

    // A small starter set so the Reminders tab and the report's reminder view
    // aren't empty on first run.
    final createdMs = nowDt.millisecondsSinceEpoch;
    reminders = [
      Reminder(
        id: 'r1',
        alarmId: 1000,
        label: 'Vitamin D drops',
        category: ReminderCategory.vitamins,
        mode: ReminderMode.fixed,
        fixedTime: '09:00',
        intervalHours: 0,
        nextDueAt: Reminder.nextFixedOccurrence('09:00', nowDt).millisecondsSinceEpoch,
        createdAt: createdMs,
      ),
      Reminder(
        id: 'r2',
        alarmId: 1001,
        label: 'Tummy time',
        category: ReminderCategory.tummyTime,
        mode: ReminderMode.interval,
        fixedTime: '',
        intervalHours: 4,
        nextDueAt: nowDt.add(const Duration(hours: 4)).millisecondsSinceEpoch,
        createdAt: createdMs,
      ),
    ];
    _nextReminderAlarmId = 1002;
    // One completed reminder today so the report's "Done" row + counts show.
    reminderLogs = [
      ReminderLog(id: 'rl1', reminderId: 'r1', label: 'Vitamin D drops', category: ReminderCategory.vitamins, date: dateStr(nowDt), time: '09:00'),
    ];

    // A couple of sample diaper changes (one today) so the Diapers tab and the
    // report's diaper view aren't empty on first run.
    diapers = [
      Diaper(id: 'd1', date: dateStr(yest), time: '08:20', type: DiaperType.pee, peeColor: PeeColor.yellow),
      Diaper(id: 'd2', date: dateStr(yest), time: '14:10', type: DiaperType.both, peeColor: PeeColor.pale, poopColor: PoopColor.brown, poopAmount: 'Medium'),
      Diaper(id: 'd3', date: dateStr(nowDt), time: '07:15', type: DiaperType.poop, poopColor: PoopColor.yellow, poopAmount: 'Small'),
    ];
  }

  Future<void> _persistAll() async {
    await storage.saveFeeds(feeds);
    await storage.saveDiapers(diapers);
    await storage.saveBabyName(babyName);
    await storage.saveUnitPref(unitPref);
    await storage.saveDarkMode(darkMode);
    await storage.saveReminderIntervalMin(reminderIntervalMin);
    await storage.saveNextReminderAt(nextReminderAt);
    await storage.saveReminderDismissed(reminderDismissed);
    await storage.saveAlarmSound(alarmSound);
    await storage.saveAlarmVolume(alarmVolume);
    await storage.saveCustomTimerAt(customTimerAt);
    await storage.saveCustomTimerLabel(customTimerLabel);
    await storage.saveReminders(reminders);
    await storage.saveReminderLogs(reminderLogs);
    await storage.saveNextReminderAlarmId(_nextReminderAlarmId);
  }

  /// Stops a currently sounding alarm immediately. Clears the in-app overlay
  /// flag for a snappy response and stops the native alarm; the ringing-stream
  /// subscription will confirm the change. Callers reschedule (or dismiss) the
  /// underlying reminder separately.
  Future<void> _stopRinging() async {
    _alarmRinging = false;
    await notifications.cancelReminder();
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
          volume: alarmVolume,
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
          volume: alarmVolume,
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
      await _rescheduleNotification();
    }
    notifyListeners();
  }

  Future<void> deleteFeed(String id) async {
    feeds = feeds.where((f) => f.id != id).toList();
    await storage.saveFeeds(feeds);
    notifyListeners();
  }

  // --- Diapers (logging/reporting only, no scheduling) ----------------------

  String newDiaperId() => 'd${_uuid.v4()}';

  /// Saves a diaper change (new or edited). Unlike feeds, diapers never touch
  /// the reminder — they're log-only.
  Future<void> saveDiaper(Diaper diaper, {required bool isNew}) async {
    diapers = isNew ? [...diapers, diaper] : diapers.map((d) => d.id == diaper.id ? diaper : d).toList();
    diapers.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    await storage.saveDiapers(diapers);
    notifyListeners();
  }

  Future<void> deleteDiaper(String id) async {
    diapers = diapers.where((d) => d.id != id).toList();
    await storage.saveDiapers(diapers);
    notifyListeners();
  }

  /// Diaper changes on [date], earliest first.
  List<Diaper> diapersForDate(String date) {
    final list = diapers.where((d) => d.date == date).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  /// Tallies for the diaper stats row. A "both" change counts toward both the
  /// pee and the poop totals.
  DiaperStats diaperStatsFor(List<Diaper> list) {
    final pee = list.where((d) => d.hasPee).length;
    final poop = list.where((d) => d.hasPoop).length;
    return DiaperStats(total: list.length, peeCount: pee, poopCount: poop);
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

  /// Toggles the dark theme. The root App reads [darkMode] on the next build
  /// and swaps the active palette, so the whole tree re-themes at once.
  Future<void> setDarkMode(bool on) async {
    darkMode = on;
    // Swap the active palette up front so every listener that rebuilds on this
    // notify — including an already-open Settings sheet — reads the new theme's
    // tokens in the same frame, not one frame late.
    applyPalette(dark: on);
    await storage.saveDarkMode(on);
    notifyListeners();
  }

  Future<void> setReminderInterval(int minutes) async {
    reminderIntervalMin = minutes;
    nextReminderAt = DateTime.now().millisecondsSinceEpoch + minutes * 60000;
    reminderDismissed = false;
    await storage.saveReminderIntervalMin(minutes);
    await storage.saveNextReminderAt(nextReminderAt);
    await storage.saveReminderDismissed(reminderDismissed);
    _alarmRinging = false;
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
    await _stopRinging();
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
    await _stopRinging();
    await _rescheduleNotification();
    notifyListeners();
  }

  // --- Custom on-demand timer -----------------------------------------------

  /// Starts (or replaces) a user-set countdown of [duration]. It immediately
  /// takes over the reminder banner and the alarm; any custom timer already
  /// running is replaced.
  Future<void> startCustomTimer(Duration duration, {String label = 'Timer'}) async {
    _alarmRinging = false;
    customTimerAt = DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
    customTimerLabel = label.trim().isEmpty ? 'Timer' : label.trim();
    await storage.saveCustomTimerAt(customTimerAt);
    await storage.saveCustomTimerLabel(customTimerLabel);
    await _rescheduleNotification();
    notifyListeners();
  }

  /// Cancels the custom timer (whether counting down or ringing) and restores
  /// the feed reminder.
  Future<void> cancelCustomTimer() async {
    if (customTimerAt == null) return;
    customTimerAt = null;
    _alarmRinging = false;
    await storage.saveCustomTimerAt(null);
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
    _alarmRinging = false;
    await storage.saveCustomTimerAt(customTimerAt);
    await _rescheduleNotification();
    notifyListeners();
  }

  Future<void> setAlarmSound(String id) async {
    alarmSound = resolveAlarmSoundId(id);
    await storage.saveAlarmSound(alarmSound);
    // Re-arm the pending alarm so it picks up the new sound.
    await _rescheduleNotification();
    notifyListeners();
  }

  Future<void> setAlarmVolume(double volume) async {
    alarmVolume = volume.clamp(0.0, 1.0);
    await storage.saveAlarmVolume(alarmVolume);
    // Applies to the next time the alarm is (re)armed; the value is read at
    // schedule time. Avoids rescheduling on every slider movement.
    notifyListeners();
  }

  /// Plays a short, non-looping preview of the given (or current) sound.
  Future<void> previewAlarm([String? id]) =>
      alarm.previewSound(soundId: id ?? alarmSound, volume: alarmVolume);

  // --- Reminders (non-feed care alarms) -------------------------------------

  String newReminderId() => 'r${_uuid.v4()}';
  String _newReminderLogId() => 'rl${_uuid.v4()}';

  /// The other fixed-time reminder already using [hhmm], if any — used to block
  /// duplicate clock times and name the conflict in the inline error. Interval
  /// reminders are exempt (their due time drifts, so it can't collide).
  Reminder? fixedTimeConflict(String hhmm, {String? excludeId}) {
    for (final r in reminders) {
      if (r.id == excludeId) continue;
      if (r.isFixed && r.fixedTime == hhmm) return r;
    }
    return null;
  }

  /// Allocates the next free native alarm id for a new reminder.
  int _allocReminderAlarmId() => _nextReminderAlarmId++;

  /// Computes when a reminder should first come due after being created/edited.
  int _initialDueAt(ReminderMode mode, String fixedTime, int intervalHours) {
    final n = DateTime.now();
    if (mode == ReminderMode.fixed) {
      return Reminder.nextFixedOccurrence(fixedTime, n).millisecondsSinceEpoch;
    }
    return n.add(Duration(hours: intervalHours)).millisecondsSinceEpoch;
  }

  /// Creates a reminder from the Add/Edit sheet's fields. Assigns a stable
  /// alarm id + first due time and arms its alarm. Returns the created reminder.
  Future<Reminder> addReminder({
    required String label,
    required ReminderCategory category,
    required ReminderMode mode,
    required String fixedTime,
    required int intervalHours,
  }) async {
    final reminder = Reminder(
      id: newReminderId(),
      alarmId: _allocReminderAlarmId(),
      label: label.trim(),
      category: category,
      mode: mode,
      fixedTime: mode == ReminderMode.fixed ? fixedTime : '',
      intervalHours: mode == ReminderMode.interval ? intervalHours : 0,
      nextDueAt: _initialDueAt(mode, fixedTime, intervalHours),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    reminders = [...reminders, reminder];
    await storage.saveReminders(reminders);
    await storage.saveNextReminderAlarmId(_nextReminderAlarmId);
    await _armReminder(reminder);
    notifyListeners();
    return reminder;
  }

  /// Applies edits to an existing reminder. Its schedule (and next due time) is
  /// recomputed and the alarm re-armed.
  Future<void> updateReminder(
    String id, {
    required String label,
    required ReminderCategory category,
    required ReminderMode mode,
    required String fixedTime,
    required int intervalHours,
  }) async {
    reminders = reminders.map((r) {
      if (r.id != id) return r;
      return r.copyWith(
        label: label.trim(),
        category: category,
        mode: mode,
        fixedTime: mode == ReminderMode.fixed ? fixedTime : '',
        intervalHours: mode == ReminderMode.interval ? intervalHours : 0,
        nextDueAt: _initialDueAt(mode, fixedTime, intervalHours),
      );
    }).toList();
    await storage.saveReminders(reminders);
    final updated = reminders.firstWhere((r) => r.id == id);
    await _armReminder(updated);
    notifyListeners();
  }

  Future<void> deleteReminder(String id) async {
    Reminder? removed;
    for (final r in reminders) {
      if (r.id == id) removed = r;
    }
    reminders = reminders.where((r) => r.id != id).toList();
    if (removed != null) {
      try {
        await notifications.cancelAlarm(removed.alarmId);
      } catch (_) {}
    }
    if (_ringingReminderId == id) _ringingReminderId = null;
    await storage.saveReminders(reminders);
    notifyListeners();
  }

  /// Marks a reminder done: appends a completion log at the current time and
  /// reschedules its next occurrence (fixed → tomorrow at the same time,
  /// interval → now + N hours). Stops it ringing if it currently is.
  Future<void> markReminderDone(Reminder reminder) async {
    final n = DateTime.now();
    reminderLogs = [
      ...reminderLogs,
      ReminderLog(
        id: _newReminderLogId(),
        reminderId: reminder.id,
        label: reminder.label,
        category: reminder.category,
        date: dateStr(n),
        time: timeStr(n),
      ),
    ];
    await storage.saveReminderLogs(reminderLogs);
    await _rescheduleReminder(reminder, from: n);
  }

  /// Snoozes a due reminder 15 minutes from now.
  Future<void> snoozeReminderItem(Reminder reminder) async {
    final at = DateTime.now().add(const Duration(minutes: 15));
    await _rescheduleReminder(reminder, explicitNext: at);
  }

  /// Dismisses a due reminder without logging a completion — it moves on to its
  /// next occurrence (fixed → next day; interval → now + N). A fixed reminder
  /// dismissed this way still counts as "missed" for the day in the report.
  Future<void> dismissReminderItem(Reminder reminder) async {
    await _rescheduleReminder(reminder, from: DateTime.now());
  }

  /// Advances a reminder to its next occurrence and re-arms its alarm. When
  /// [explicitNext] is given (snooze) it is used directly; otherwise the next
  /// occurrence is derived from [from] per the reminder's mode.
  Future<void> _rescheduleReminder(Reminder reminder, {DateTime? from, DateTime? explicitNext}) async {
    final base = from ?? DateTime.now();
    final DateTime next;
    if (explicitNext != null) {
      next = explicitNext;
    } else if (reminder.isFixed) {
      // Strictly after `base` so a just-completed reminder rolls to the next day
      // rather than re-firing at the same clock time today.
      next = Reminder.nextFixedOccurrence(reminder.fixedTime, base);
    } else {
      next = base.add(Duration(hours: reminder.intervalHours));
    }
    reminders = reminders
        .map((r) => r.id == reminder.id ? r.copyWith(nextDueAt: next.millisecondsSinceEpoch) : r)
        .toList();
    if (_ringingReminderId == reminder.id) _ringingReminderId = null;
    await storage.saveReminders(reminders);
    final updated = reminders.firstWhere((r) => r.id == reminder.id);
    try {
      await notifications.cancelAlarm(reminder.alarmId);
    } catch (_) {}
    await _armReminder(updated);
    notifyListeners();
  }

  /// Arms (or re-arms) the native full-screen alarm for a single reminder at its
  /// current [Reminder.nextDueAt]. Guarded so a device scheduling failure can't
  /// stop the in-app state update.
  Future<void> _armReminder(Reminder reminder) async {
    try {
      await notifications.scheduleAlarmAt(
        id: reminder.alarmId,
        at: DateTime.fromMillisecondsSinceEpoch(reminder.nextDueAt),
        title: reminder.label.isNotEmpty ? reminder.label : 'Reminder',
        body: reminderCategories[reminder.category]!.label,
        soundId: alarmSound,
        volume: alarmVolume,
      );
    } catch (e) {
      debugPrint('Failed to arm reminder alarm: $e');
    }
  }

  /// Re-arms every reminder's alarm (called once on load) so care reminders keep
  /// firing after the app has been closed.
  Future<void> _rescheduleAllReminders() async {
    for (final r in reminders) {
      await _armReminder(r);
    }
  }

  /// Completion + quick logs recorded on [date], earliest first.
  List<ReminderLog> reminderLogsForDate(String date) {
    final list = reminderLogs.where((l) => l.date == date).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  /// Scheduled-reminder completions on [date] (the report's "Completed" count).
  List<ReminderLog> completedLogsForDate(String date) =>
      reminderLogsForDate(date).where((l) => !l.isQuickLog).toList();

  /// Ad-hoc quick logs on [date] (the report's "Logged" count + white rows).
  List<ReminderLog> quickLogsForDate(String date) =>
      reminderLogsForDate(date).where((l) => l.isQuickLog).toList();

  // --- Quick log (ad-hoc category logging, no schedule) ---------------------

  /// Logs a category on the spot: appends an ad-hoc [ReminderLog] (reminderId
  /// null) at today's date and the current time, with no note and no schedule.
  /// Returns it so the caller can show the confirmation toast.
  Future<ReminderLog> quickLog(ReminderCategory category) async {
    final n = DateTime.now();
    final log = ReminderLog(
      id: _newReminderLogId(),
      reminderId: null,
      label: reminderCategories[category]!.label,
      category: category,
      date: dateStr(n),
      time: timeStr(n),
    );
    reminderLogs = [...reminderLogs, log];
    await storage.saveReminderLogs(reminderLogs);
    notifyListeners();
    return log;
  }

  /// Edits the date/time of a log (used by the report's compact edit sheet;
  /// quick logs are the only rows the report makes editable).
  Future<void> updateReminderLog(String id, {required String date, required String time}) async {
    reminderLogs = reminderLogs.map((l) => l.id == id ? l.copyWith(date: date, time: time) : l).toList();
    await storage.saveReminderLogs(reminderLogs);
    notifyListeners();
  }

  Future<void> deleteReminderLog(String id) async {
    reminderLogs = reminderLogs.where((l) => l.id != id).toList();
    await storage.saveReminderLogs(reminderLogs);
    notifyListeners();
  }

  /// Fixed-time reminders that came due on [date] but have no completion logged
  /// that day — the report's grayed "Missed" rows. Only considers dates from a
  /// reminder's creation day up to today (a reminder can't be missed before it
  /// existed, or on a future day).
  List<MissedReminder> missedRemindersForDate(String date) {
    final result = <MissedReminder>[];
    final n = DateTime.now();
    final todayStr = dateStr(n);
    if (date.compareTo(todayStr) > 0) return result; // future day
    for (final r in reminders) {
      if (!r.isFixed) continue;
      final createdStr = dateStr(DateTime.fromMillisecondsSinceEpoch(r.createdAt));
      if (date.compareTo(createdStr) < 0) continue; // before it existed
      // On today, the deadline must already have passed.
      if (date == todayStr) {
        final due = DateTime.parse('${date}T${r.fixedTime}:00');
        if (due.isAfter(n)) continue;
      }
      final doneThatDay = reminderLogs.any((l) => l.reminderId == r.id && l.date == date);
      if (!doneThatDay) result.add(MissedReminder(r, r.fixedTime));
    }
    return result;
  }

  // --- Backup & restore ------------------------------------------------------
  // All state is on-device, so an uninstall (or the one-time signing-key
  // reinstall) would otherwise wipe it. These let the user save everything to
  // a JSON file they keep, and read it back.

  static const backupVersion = 3;

  /// Serialises every feed, diaper, reminder and setting to a portable JSON
  /// string.
  String exportData() => jsonEncode({
        'app': 'baby_feed_tracker',
        'version': backupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'babyName': babyName,
        'unitPref': unitPref,
        'darkMode': darkMode,
        'reminderIntervalMin': reminderIntervalMin,
        'alarmSound': alarmSound,
        'alarmVolume': alarmVolume,
        'feeds': feeds.map((f) => f.toJson()).toList(),
        'diapers': diapers.map((d) => d.toJson()).toList(),
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'reminderLogs': reminderLogs.map((l) => l.toJson()).toList(),
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
      darkMode = (data['darkMode'] as bool?) ?? darkMode;
      reminderIntervalMin = (data['reminderIntervalMin'] as int?) ?? reminderIntervalMin;
      alarmSound = resolveAlarmSoundId(data['alarmSound'] as String?);
      alarmVolume = ((data['alarmVolume'] as num?)?.toDouble() ?? alarmVolume).clamp(0.0, 1.0);

      // Diapers, like reminders, are only replaced when the backup actually
      // carries them, so restoring an older backup (v1/v2, no diapers key)
      // leaves existing diapers intact.
      if (data.containsKey('diapers')) {
        diapers = (data['diapers'] as List<dynamic>)
            .map((e) => Diaper.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
      }

      // Reminders are only replaced when the backup actually carries them, so
      // restoring an older feeds-only backup leaves existing reminders intact.
      if (data.containsKey('reminders')) {
        reminders = (data['reminders'] as List<dynamic>)
            .map((e) => Reminder.fromJson(e as Map<String, dynamic>))
            .toList();
        // Keep the alarm-id counter ahead of every imported reminder so newly
        // added ones never reuse a live alarm id.
        for (final r in reminders) {
          if (r.alarmId >= _nextReminderAlarmId) _nextReminderAlarmId = r.alarmId + 1;
        }
      }
      if (data.containsKey('reminderLogs')) {
        reminderLogs = (data['reminderLogs'] as List<dynamic>)
            .map((e) => ReminderLog.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      await _persistAll();
      await _rescheduleAllReminders();
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
