import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/appointment.dart';
import '../models/diaper.dart';
import '../models/feed.dart';
import '../models/reminder.dart';
import '../models/weight.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

const mlPerOz = 29.5735;
const lbPerKg = 2.2046226218; // 1 kg in pounds; weight is stored canonically in kg
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
  List<Weight> weights = [];
  /// The remembered, reusable feed-tag vocabulary — every tag ever attached to
  /// a feed, in first-seen order, so the log-feed sheet can offer them again.
  List<String> feedTags = [];
  List<Reminder> reminders = [];
  List<ReminderLog> reminderLogs = [];
  List<Appointment> appointments = [];
  int _nextReminderAlarmId = 1000;
  String babyName = '';
  String unitPref = 'ml';
  String weightUnitPref = 'kg';
  bool darkMode = false;
  int reminderIntervalMin = 180;
  int nextReminderAt = 0;
  bool reminderDismissed = false;
  String alarmSound = kDefaultAlarmSound;
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
  String? _ringingAppointmentId;
  bool _ringingAppointmentIsLead = false;

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

  /// The appointment whose full-screen alarm is currently sounding, if any.
  Appointment? get ringingAppointment {
    if (_ringingAppointmentId == null) return null;
    for (final a in appointments) {
      if (a.id == _ringingAppointmentId) return a;
    }
    return null;
  }

  /// Whether the currently ringing appointment alarm is its *lead* (1h/1d
  /// heads-up) rather than the at-time alarm — the overlay shows fewer actions
  /// for a lead alarm (you can't be "done" before the appointment happens).
  bool get ringingAppointmentIsLead => _ringingAppointmentIsLead;

  /// Appointments whose time has passed and were never resolved — shown as
  /// "overdue" cards at the top of the Appointments tab, earliest first.
  List<Appointment> get overdueAppointments {
    final list = appointments.where((a) => a.isOverdue(now)).toList()
      ..sort((a, b) => a.atMs.compareTo(b.atMs));
    return list;
  }

  /// Upcoming (not-yet-due, not-done) appointments, soonest first.
  List<Appointment> get upcomingAppointments {
    final nowMs = now.millisecondsSinceEpoch;
    final list = appointments.where((a) => !a.isDone && a.atMs >= nowMs).toList()
      ..sort((a, b) => a.atMs.compareTo(b.atMs));
    return list;
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
    // A fresh install starts empty — no sample/seed data is written. Every
    // screen has its own empty state, so there is nothing to clear on first run.
    feeds = storage.loadFeeds();
    feedTags = storage.loadFeedTags();
    diapers = storage.loadDiapers();
    weights = storage.loadWeights();
    reminders = storage.loadReminders();
    reminderLogs = storage.loadReminderLogs();
    appointments = storage.loadAppointments();
    _nextReminderAlarmId = storage.loadNextReminderAlarmId();
    babyName = storage.loadBabyName() ?? '';
    unitPref = storage.loadUnitPref();
    weightUnitPref = storage.loadWeightUnitPref();
    darkMode = storage.loadDarkMode();
    reminderIntervalMin = storage.loadReminderIntervalMin();
    nextReminderAt = storage.loadNextReminderAt() ??
        DateTime.now().add(Duration(minutes: reminderIntervalMin)).millisecondsSinceEpoch;
    reminderDismissed = storage.loadReminderDismissed();
    alarmSound = resolveAlarmSoundId(storage.loadAlarmSound());
    customTimerAt = storage.loadCustomTimerAt();
    customTimerLabel = storage.loadCustomTimerLabel() ?? 'Timer';
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
      String? apptId;
      var apptIsLead = false;
      for (final a in appointments) {
        if (ids.contains(a.atAlarmId)) {
          apptId = a.id;
          apptIsLead = false;
          break;
        }
        if (ids.contains(a.leadAlarmId)) {
          apptId = a.id;
          apptIsLead = true;
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
      if (apptId != _ringingAppointmentId || apptIsLead != _ringingAppointmentIsLead) {
        _ringingAppointmentId = apptId;
        _ringingAppointmentIsLead = apptIsLead;
        changed = true;
      }
      if (changed) notifyListeners();
    });
    // Make sure a real OS alarm is armed for any pending reminder/timer/care
    // reminder, so they still fire when the app is later closed — previously the
    // notification was only (re)scheduled when the user changed something.
    await _rescheduleNotification();
    await _rescheduleAllReminders();
    await _rescheduleAllAppointments();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    notifications.dispose();
    alarm.dispose();
    super.dispose();
  }

  Future<void> _persistAll() async {
    await storage.saveFeeds(feeds);
    await storage.saveFeedTags(feedTags);
    await storage.saveDiapers(diapers);
    await storage.saveWeights(weights);
    await storage.saveBabyName(babyName);
    await storage.saveUnitPref(unitPref);
    await storage.saveWeightUnitPref(weightUnitPref);
    await storage.saveDarkMode(darkMode);
    await storage.saveReminderIntervalMin(reminderIntervalMin);
    await storage.saveNextReminderAt(nextReminderAt);
    await storage.saveReminderDismissed(reminderDismissed);
    await storage.saveAlarmSound(alarmSound);
    await storage.saveCustomTimerAt(customTimerAt);
    await storage.saveCustomTimerLabel(customTimerLabel);
    await storage.saveReminders(reminders);
    await storage.saveReminderLogs(reminderLogs);
    await storage.saveAppointments(appointments);
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
  /// Adds any tags not already known (case-insensitive) to the reusable
  /// vocabulary, preserving first-seen order and the original casing. Returns
  /// whether the vocabulary changed.
  bool _mergeFeedTags(Iterable<String> tags) {
    var changed = false;
    for (final raw in tags) {
      final tag = raw.trim();
      if (tag.isEmpty) continue;
      final exists = feedTags.any((t) => t.toLowerCase() == tag.toLowerCase());
      if (!exists) {
        feedTags = [...feedTags, tag];
        changed = true;
      }
    }
    return changed;
  }

  Future<void> saveFeed(Feed feed, {required bool isNew}) async {
    feeds = isNew ? [...feeds, feed] : feeds.map((f) => f.id == feed.id ? feed : f).toList();
    feeds.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    // Remember any new tags so they can be reused on future feeds.
    if (_mergeFeedTags(feed.tags)) {
      await storage.saveFeedTags(feedTags);
    }
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

  // --- Weights (logging only, no schedule) ----------------------------------

  String newWeightId() => 'w${_uuid.v4()}';

  /// Weigh-ins oldest → newest. The canonical order for computing the
  /// "change since the previous entry" deltas.
  List<Weight> get weightsAscending {
    final list = [...weights]..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return list;
  }

  /// Weigh-ins newest → oldest, for the reverse-chronological history list.
  List<Weight> get weightsDescending => weightsAscending.reversed.toList();

  /// The most recent weigh-in, or null when none have been logged.
  Weight? get latestWeight {
    final asc = weightsAscending;
    return asc.isEmpty ? null : asc.last;
  }

  /// The kg change of [w] since the chronologically previous weigh-in, or null
  /// when it's the earliest entry (nothing to compare against). Drives the
  /// history rows' delta pills.
  double? weightDeltaKg(Weight w) {
    final asc = weightsAscending;
    final i = asc.indexWhere((x) => x.id == w.id);
    if (i <= 0) return null;
    return w.kg - asc[i - 1].kg;
  }

  /// Saves a weigh-in (new or edited). Like diapers, weights never touch the
  /// feed reminder — they're log-only.
  Future<void> saveWeight(Weight weight, {required bool isNew}) async {
    weights = isNew ? [...weights, weight] : weights.map((w) => w.id == weight.id ? weight : w).toList();
    weights.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    await storage.saveWeights(weights);
    notifyListeners();
  }

  Future<void> deleteWeight(String id) async {
    weights = weights.where((w) => w.id != id).toList();
    await storage.saveWeights(weights);
    notifyListeners();
  }

  Future<void> setWeightUnitPref(String unit) async {
    weightUnitPref = unit;
    await storage.saveWeightUnitPref(unit);
    notifyListeners();
  }

  /// Converts a canonical kg value into the current display unit (kg or lb).
  double kgToDisplayUnit(double kg) => weightUnitPref == 'lb' ? kg * lbPerKg : kg;

  /// A weight formatted to exactly 2 decimals in the current unit, e.g.
  /// "4.50 kg" or "9.92 lb". Used for the latest card and history rows.
  String weightLabel(double kg) => '${kgToDisplayUnit(kg).toStringAsFixed(2)} $weightUnitPref';

  /// A signed delta formatted to exactly 2 decimals in the current unit, e.g.
  /// "+0.45 kg" or "-0.10 lb". Used for the history rows' delta pills.
  String weightDeltaLabel(double kgDelta) {
    final v = weightUnitPref == 'lb' ? kgDelta * lbPerKg : kgDelta;
    final sign = v < 0 ? '-' : '+';
    return '$sign${v.abs().toStringAsFixed(2)} $weightUnitPref';
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

  /// Nudges the feed reminder's due time forward by [minutes] — the banner's
  /// "+5m / +15m / +30m" actions. Stackable (each call adds to the last). When
  /// the reminder is already overdue we anchor to now so the nudge always lands
  /// in the future and clears the overdue state, mirroring the custom timer's
  /// "+5 min". This is a one-off nudge to the current countdown; it never
  /// touches the default interval preset. Only reachable while the feed
  /// reminder banner is showing (no custom timer covering it).
  Future<void> addReminderTime(int minutes) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final base = nextReminderAt < nowMs ? nowMs : nextReminderAt;
    nextReminderAt = base + minutes * 60000;
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

  /// Plays a short, non-looping preview of the given (or current) sound at the
  /// device's alarm volume — the same loudness a real reminder will ring at.
  Future<void> previewAlarm([String? id]) =>
      alarm.previewSound(soundId: id ?? alarmSound);

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

  /// Marks a *missed* fixed-time reminder done after the fact ("Missed → Mark
  /// done late"). Appends a completion for [date] — today when triggered from
  /// the Reminders tab, or the viewed day when triggered from the report —
  /// timestamped at the current time (never backdated) and flagged
  /// [ReminderLog.isLate] so it shows as "Done (late)".
  ///
  /// The reminder's schedule is deliberately left untouched: it keeps firing at
  /// its normal daily fixed time. The late completion is purely a log entry, so
  /// (a log now existing for that day) the day's "Missed" state clears on its
  /// own.
  Future<void> markReminderDoneLate(Reminder reminder, {required String date}) async {
    final n = DateTime.now();
    reminderLogs = [
      ...reminderLogs,
      ReminderLog(
        id: _newReminderLogId(),
        reminderId: reminder.id,
        label: reminder.label,
        category: reminder.category,
        date: date,
        time: timeStr(n),
        isLate: true,
      ),
    ];
    await storage.saveReminderLogs(reminderLogs);
    notifyListeners();
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

  /// Whether fixed-time [r] is currently "missed" for today — its clock time
  /// has passed and nothing has been logged for it today. Drives the tappable
  /// "Missed" tag on the Reminders tab; same rule the report uses per day. Uses
  /// the live [now] so it flips on as the day crosses the reminder's time.
  bool isMissedNow(Reminder r) {
    if (!r.isFixed) return false;
    final n = now;
    final todayStr = dateStr(n);
    final createdStr = dateStr(DateTime.fromMillisecondsSinceEpoch(r.createdAt));
    if (todayStr.compareTo(createdStr) < 0) return false; // before it existed
    final due = DateTime.parse('${todayStr}T${r.fixedTime}:00');
    if (due.isAfter(n)) return false; // deadline not yet reached
    return !reminderLogs.any((l) => l.reminderId == r.id && l.date == todayStr);
  }

  // --- Appointments (one-off dated events) ----------------------------------

  String newAppointmentId() => 'a${_uuid.v4()}';

  /// Creates an appointment from the Add/Edit sheet's fields. Allocates its two
  /// stable alarm ids (lead + at-time) and arms both. Returns the created one.
  Future<Appointment> addAppointment({
    required String title,
    required AppointmentCategory category,
    required int atMs,
    required AppointmentLead lead,
    required String description,
  }) async {
    final appointment = Appointment(
      id: newAppointmentId(),
      leadAlarmId: _allocReminderAlarmId(),
      atAlarmId: _allocReminderAlarmId(),
      title: title.trim(),
      category: category,
      atMs: atMs,
      lead: lead,
      description: description.trim(),
      doneAtMs: null,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    appointments = [...appointments, appointment];
    await storage.saveAppointments(appointments);
    await storage.saveNextReminderAlarmId(_nextReminderAlarmId);
    await _armAppointment(appointment);
    notifyListeners();
    return appointment;
  }

  /// Applies edits to an appointment, keeping its alarm ids, and re-arms both
  /// alarms for the (possibly new) time. Editing does not clear a "done" state.
  Future<void> updateAppointment(
    String id, {
    required String title,
    required AppointmentCategory category,
    required int atMs,
    required AppointmentLead lead,
    required String description,
  }) async {
    Appointment? updated;
    appointments = appointments.map((a) {
      if (a.id != id) return a;
      updated = a.copyWith(
        title: title.trim(),
        category: category,
        atMs: atMs,
        lead: lead,
        description: description.trim(),
      );
      return updated!;
    }).toList();
    await storage.saveAppointments(appointments);
    if (updated != null) await _armAppointment(updated!);
    notifyListeners();
  }

  Future<void> deleteAppointment(String id) async {
    Appointment? removed;
    for (final a in appointments) {
      if (a.id == id) removed = a;
    }
    appointments = appointments.where((a) => a.id != id).toList();
    if (removed != null) {
      try {
        await notifications.cancelAlarm(removed.leadAlarmId);
        await notifications.cancelAlarm(removed.atAlarmId);
      } catch (_) {}
    }
    if (_ringingAppointmentId == id) _ringingAppointmentId = null;
    await storage.saveAppointments(appointments);
    notifyListeners();
  }

  /// Marks an appointment done (records the moment) and cancels both its alarms.
  /// A done appointment shows in the daily report and drops off the Appointments
  /// tab.
  Future<void> markAppointmentDone(Appointment appointment) async {
    appointments = appointments
        .map((a) => a.id == appointment.id
            ? a.copyWith(doneAtMs: DateTime.now().millisecondsSinceEpoch)
            : a)
        .toList();
    if (_ringingAppointmentId == appointment.id) _ringingAppointmentId = null;
    await storage.saveAppointments(appointments);
    try {
      await notifications.cancelAlarm(appointment.leadAlarmId);
      await notifications.cancelAlarm(appointment.atAlarmId);
    } catch (_) {}
    notifyListeners();
  }

  /// Reschedules an appointment to [newAt] (the "Postpone" action). It stays
  /// not-done; both alarms re-arm for the new time.
  Future<void> postponeAppointment(Appointment appointment, DateTime newAt) async {
    Appointment? updated;
    appointments = appointments.map((a) {
      if (a.id != appointment.id) return a;
      updated = a.copyWith(atMs: newAt.millisecondsSinceEpoch, clearDone: true);
      return updated!;
    }).toList();
    if (_ringingAppointmentId == appointment.id) _ringingAppointmentId = null;
    await storage.saveAppointments(appointments);
    if (updated != null) await _armAppointment(updated!);
    notifyListeners();
  }

  /// Silences a ringing appointment alarm without resolving the appointment.
  /// The lead alarm is a one-shot heads-up; dismissing the at-time alarm leaves
  /// the appointment as an overdue card. Neither reschedules (appointments don't
  /// recur), so the fired alarm is simply cancelled.
  Future<void> dismissAppointmentAlarm(Appointment appointment) async {
    _ringingAppointmentId = null;
    try {
      if (_ringingAppointmentIsLead) {
        await notifications.cancelAlarm(appointment.leadAlarmId);
      } else {
        await notifications.cancelAlarm(appointment.atAlarmId);
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Arms an appointment's lead and at-time alarms — but only for moments still
  /// in the future. A past at-time (an overdue appointment reopened later) is
  /// deliberately not re-armed: it simply shows as an overdue card rather than
  /// re-ringing on every app open. A done appointment arms nothing.
  Future<void> _armAppointment(Appointment appointment) async {
    if (appointment.isDone) {
      try {
        await notifications.cancelAlarm(appointment.leadAlarmId);
        await notifications.cancelAlarm(appointment.atAlarmId);
      } catch (_) {}
      return;
    }
    final n = DateTime.now();
    final title = appointment.displayTitle;
    final catLabel = appointmentCategories[appointment.category]!.label;
    // At-time alarm.
    try {
      if (appointment.at.isAfter(n)) {
        await notifications.scheduleAlarmAt(
          id: appointment.atAlarmId,
          at: appointment.at,
          title: title,
          body: '$catLabel appointment',
          soundId: alarmSound,
        );
      } else {
        await notifications.cancelAlarm(appointment.atAlarmId);
      }
    } catch (e) {
      debugPrint('Failed to arm appointment at-time alarm: $e');
    }
    // Lead alarm (1h / 1d before), when set and still ahead.
    try {
      final leadAt = appointment.leadAt;
      if (leadAt != null && leadAt.isAfter(n)) {
        await notifications.scheduleAlarmAt(
          id: appointment.leadAlarmId,
          at: leadAt,
          title: title,
          body: '$catLabel appointment ${appointment.lead.shortLabel}',
          soundId: alarmSound,
        );
      } else {
        await notifications.cancelAlarm(appointment.leadAlarmId);
      }
    } catch (e) {
      debugPrint('Failed to arm appointment lead alarm: $e');
    }
  }

  /// Re-arms every appointment's future alarms (called once on load) so they
  /// still fire after the app has been closed.
  Future<void> _rescheduleAllAppointments() async {
    for (final a in appointments) {
      await _armAppointment(a);
    }
  }

  /// Done appointments whose scheduled day is [date] — the report shows each at
  /// its scheduled time (when it actually happened), earliest first.
  List<Appointment> doneAppointmentsForDate(String date) {
    final list = appointments.where((a) => a.isDone && a.dateStr == date).toList()
      ..sort((a, b) => a.timeStr.compareTo(b.timeStr));
    return list;
  }

  // --- Backup & restore ------------------------------------------------------
  // All state is on-device, so an uninstall (or the one-time signing-key
  // reinstall) would otherwise wipe it. These let the user save everything to
  // a JSON file they keep, and read it back.

  static const backupVersion = 5;

  /// Serialises every feed, diaper, weight, reminder and setting to a portable
  /// JSON string.
  String exportData() => jsonEncode({
        'app': 'baby_feed_tracker',
        'version': backupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'babyName': babyName,
        'unitPref': unitPref,
        'weightUnitPref': weightUnitPref,
        'darkMode': darkMode,
        'reminderIntervalMin': reminderIntervalMin,
        'alarmSound': alarmSound,
        'feeds': feeds.map((f) => f.toJson()).toList(),
        'feedTags': feedTags,
        'diapers': diapers.map((d) => d.toJson()).toList(),
        'weights': weights.map((w) => w.toJson()).toList(),
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'reminderLogs': reminderLogs.map((l) => l.toJson()).toList(),
        'appointments': appointments.map((a) => a.toJson()).toList(),
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
      // Restore the saved tag vocabulary when present, then make sure every tag
      // actually used by an imported feed is in it (older backups predating the
      // vocabulary still repopulate it from their feeds).
      if (data.containsKey('feedTags')) {
        feedTags = (data['feedTags'] as List<dynamic>).map((e) => e as String).toList();
      }
      _mergeFeedTags(imported.expand((f) => f.tags));
      babyName = (data['babyName'] as String?) ?? babyName;
      unitPref = (data['unitPref'] as String?) ?? unitPref;
      weightUnitPref = (data['weightUnitPref'] as String?) ?? weightUnitPref;
      darkMode = (data['darkMode'] as bool?) ?? darkMode;
      reminderIntervalMin = (data['reminderIntervalMin'] as int?) ?? reminderIntervalMin;
      alarmSound = resolveAlarmSoundId(data['alarmSound'] as String?);

      // Diapers, like reminders, are only replaced when the backup actually
      // carries them, so restoring an older backup (v1/v2, no diapers key)
      // leaves existing diapers intact.
      if (data.containsKey('diapers')) {
        diapers = (data['diapers'] as List<dynamic>)
            .map((e) => Diaper.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
      }

      // Weights, like diapers, are only replaced when the backup actually
      // carries them, so restoring an older backup (no weights key) leaves
      // existing weigh-ins intact.
      if (data.containsKey('weights')) {
        weights = (data['weights'] as List<dynamic>)
            .map((e) => Weight.fromJson(e as Map<String, dynamic>))
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

      // Appointments, like reminders, are only replaced when the backup carries
      // them, so an older backup (no appointments key) leaves existing ones
      // intact. Keep the shared alarm-id counter ahead of every imported
      // appointment's two ids so newly added items never reuse a live alarm id.
      if (data.containsKey('appointments')) {
        appointments = (data['appointments'] as List<dynamic>)
            .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final a in appointments) {
          if (a.leadAlarmId >= _nextReminderAlarmId) _nextReminderAlarmId = a.leadAlarmId + 1;
          if (a.atAlarmId >= _nextReminderAlarmId) _nextReminderAlarmId = a.atAlarmId + 1;
        }
      }

      await _persistAll();
      await _rescheduleAllReminders();
      await _rescheduleAllAppointments();
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
