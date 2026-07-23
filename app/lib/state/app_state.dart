import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/feed.dart';
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

  AppState(this.storage, this.notifications);

  List<Feed> feeds = [];
  String babyName = '';
  String unitPref = 'ml';
  int reminderIntervalMin = 180;
  int nextReminderAt = 0;
  bool reminderDismissed = false;
  DateTime now = DateTime.now();

  Timer? _ticker;

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
    }
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      now = DateTime.now();
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
  }

  /// Scheduling can fail on-device (e.g. exact-alarm permission revoked by
  /// the OEM after install) — never let that exception stop the caller from
  /// reaching notifyListeners(), since the in-app state update must not
  /// depend on the OS notification succeeding.
  Future<void> _rescheduleNotification() async {
    try {
      if (reminderDismissed) {
        await notifications.cancelReminder();
      } else {
        await notifications.scheduleReminder(
          DateTime.fromMillisecondsSinceEpoch(nextReminderAt),
          babyName: babyName,
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
    if (isNew) {
      nextReminderAt = dtToMs(feed.date, feed.time) + reminderIntervalMin * 60000;
      reminderDismissed = false;
    }
    await storage.saveFeeds(feeds);
    if (isNew) {
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
    await storage.saveReminderIntervalMin(minutes);
    await storage.saveNextReminderAt(nextReminderAt);
    await _rescheduleNotification();
    notifyListeners();
  }

  Future<void> snoozeReminder() async {
    nextReminderAt = DateTime.now().millisecondsSinceEpoch + 15 * 60000;
    reminderDismissed = false;
    await storage.saveNextReminderAt(nextReminderAt);
    await storage.saveReminderDismissed(reminderDismissed);
    await _rescheduleNotification();
    notifyListeners();
  }

  Future<void> dismissReminder() async {
    reminderDismissed = true;
    await storage.saveReminderDismissed(true);
    await _rescheduleNotification();
    notifyListeners();
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
