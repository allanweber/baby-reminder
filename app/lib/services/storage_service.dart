import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/feed.dart';
import '../models/reminder.dart';

/// On-device persistence. This is a single-user, single-baby, offline-first
/// app — everything lives in [SharedPreferences], no backend involved.
class StorageService {
  static const _kFeeds = 'feeds';
  static const _kBabyName = 'babyName';
  static const _kUnitPref = 'unitPref';
  static const _kReminderIntervalMin = 'reminderIntervalMin';
  static const _kNextReminderAt = 'nextReminderAt';
  static const _kReminderDismissed = 'reminderDismissed';
  static const _kAlarmSound = 'alarmSound';
  static const _kAlarmVolume = 'alarmVolume';
  static const _kCustomTimerAt = 'customTimerAt';
  static const _kCustomTimerLabel = 'customTimerLabel';
  static const _kReminders = 'reminders';
  static const _kReminderLogs = 'reminderLogs';
  static const _kNextReminderAlarmId = 'nextReminderAlarmId';
  static const _kSeeded = 'seeded';

  final SharedPreferences _prefs;
  StorageService(this._prefs);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  bool get hasSeeded => _prefs.getBool(_kSeeded) ?? false;
  Future<void> markSeeded() => _prefs.setBool(_kSeeded, true);

  List<Feed> loadFeeds() {
    final raw = _prefs.getString(_kFeeds);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Feed.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveFeeds(List<Feed> feeds) async {
    final raw = jsonEncode(feeds.map((f) => f.toJson()).toList());
    await _prefs.setString(_kFeeds, raw);
  }

  String? loadBabyName() => _prefs.getString(_kBabyName);
  Future<void> saveBabyName(String name) => _prefs.setString(_kBabyName, name);

  String loadUnitPref() => _prefs.getString(_kUnitPref) ?? 'ml';
  Future<void> saveUnitPref(String unit) => _prefs.setString(_kUnitPref, unit);

  int loadReminderIntervalMin() => _prefs.getInt(_kReminderIntervalMin) ?? 180;
  Future<void> saveReminderIntervalMin(int min) => _prefs.setInt(_kReminderIntervalMin, min);

  int? loadNextReminderAt() => _prefs.getInt(_kNextReminderAt);
  Future<void> saveNextReminderAt(int millis) => _prefs.setInt(_kNextReminderAt, millis);

  bool loadReminderDismissed() => _prefs.getBool(_kReminderDismissed) ?? false;
  Future<void> saveReminderDismissed(bool dismissed) => _prefs.setBool(_kReminderDismissed, dismissed);

  String? loadAlarmSound() => _prefs.getString(_kAlarmSound);
  Future<void> saveAlarmSound(String id) => _prefs.setString(_kAlarmSound, id);

  double loadAlarmVolume() => _prefs.getDouble(_kAlarmVolume) ?? 0.8;
  Future<void> saveAlarmVolume(double v) => _prefs.setDouble(_kAlarmVolume, v);

  int? loadCustomTimerAt() => _prefs.getInt(_kCustomTimerAt);
  Future<void> saveCustomTimerAt(int? millis) async {
    if (millis == null) {
      await _prefs.remove(_kCustomTimerAt);
    } else {
      await _prefs.setInt(_kCustomTimerAt, millis);
    }
  }

  String? loadCustomTimerLabel() => _prefs.getString(_kCustomTimerLabel);
  Future<void> saveCustomTimerLabel(String label) => _prefs.setString(_kCustomTimerLabel, label);

  List<Reminder> loadReminders() {
    final raw = _prefs.getString(_kReminders);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveReminders(List<Reminder> reminders) async {
    final raw = jsonEncode(reminders.map((r) => r.toJson()).toList());
    await _prefs.setString(_kReminders, raw);
  }

  List<ReminderLog> loadReminderLogs() {
    final raw = _prefs.getString(_kReminderLogs);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => ReminderLog.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveReminderLogs(List<ReminderLog> logs) async {
    final raw = jsonEncode(logs.map((l) => l.toJson()).toList());
    await _prefs.setString(_kReminderLogs, raw);
  }

  // Distinct alarm-id space for reminders, kept clear of the feed reminder (1)
  // and the diagnostic test alarm (2) so their native alarms never collide.
  int loadNextReminderAlarmId() => _prefs.getInt(_kNextReminderAlarmId) ?? 1000;
  Future<void> saveNextReminderAlarmId(int id) => _prefs.setInt(_kNextReminderAlarmId, id);
}
