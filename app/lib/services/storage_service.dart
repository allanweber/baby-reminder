import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/feed.dart';

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
}
