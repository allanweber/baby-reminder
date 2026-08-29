import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baby_feed_tracker/models/feed.dart';
import 'package:baby_feed_tracker/services/alarm_service.dart';
import 'package:baby_feed_tracker/services/notification_service.dart';
import 'package:baby_feed_tracker/services/storage_service.dart';
import 'package:baby_feed_tracker/state/app_state.dart';
import 'package:baby_feed_tracker/theme/app_theme.dart';

Future<AppState> _freshState() async {
  SharedPreferences.setMockInitialValues({});
  return _reloadState();
}

// Reloads from whatever is already persisted (no reset) — simulates a restart.
Future<AppState> _reloadState() async {
  final storage = await StorageService.create();
  final appState = AppState(storage, NotificationService(), AlarmService());
  await appState.load();
  return appState;
}

Feed _feedNow() {
  final now = DateTime.now();
  return Feed(
    id: 'f1',
    date: dateStr(now),
    time: timeStr(now),
    type: FeedType.breastfeeding,
    amountMl: 0,
    durationMin: 20,
    note: '',
    tags: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('automatic feed reminder toggle', () {
    test('defaults OFF, and logging a feed does not start a countdown', () async {
      final s = await _freshState();
      expect(s.feedReminderEnabled, isFalse);

      final before = s.nextReminderAt;
      await s.saveFeed(_feedNow(), isNew: true);
      // With the reminder off, logging a feed leaves the countdown target
      // untouched — no new alarm is armed.
      expect(s.nextReminderAt, before);
      expect(s.feedReminderEnabled, isFalse);
      s.dispose();
    });

    test('turning it on starts a countdown from now using the interval', () async {
      final s = await _freshState();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await s.setFeedReminderEnabled(true);

      expect(s.feedReminderEnabled, isTrue);
      expect(s.reminderDismissed, isFalse);
      // A live countdown ~= now + the default interval (180 min).
      final expected = nowMs + s.reminderIntervalMin * 60000;
      expect((s.nextReminderAt - expected).abs() < 5000, isTrue);
      s.dispose();
    });

    test('turning it off leaves a running custom timer alone', () async {
      final s = await _freshState();
      await s.setFeedReminderEnabled(true);
      await s.startCustomTimer(const Duration(minutes: 10), label: 'Nap');
      expect(s.customTimerActive, isTrue);

      await s.setFeedReminderEnabled(false);
      expect(s.feedReminderEnabled, isFalse);
      // The independent custom timer must survive turning the feed reminder off.
      expect(s.customTimerActive, isTrue);
      s.dispose();
    });

    test('the setting persists across a restart', () async {
      final s1 = await _freshState();
      await s1.setFeedReminderEnabled(true);
      s1.dispose();

      final s2 = await _reloadState();
      expect(s2.feedReminderEnabled, isTrue);
      s2.dispose();
    });

    test('the setting round-trips through export/import; legacy backups leave it unchanged', () async {
      final s = await _freshState();
      await s.setFeedReminderEnabled(true);
      final json = s.exportData();

      final s2 = await _freshState();
      expect(s2.feedReminderEnabled, isFalse);
      await s2.importData(json);
      expect(s2.feedReminderEnabled, isTrue);

      // A backup predating the toggle carries no value, so it leaves the current
      // setting untouched (a fresh install is already OFF by default).
      const legacy = '{"app":"baby_feed_tracker","version":1,"feeds":[],"babyName":"Mia"}';
      final s3 = await _freshState();
      await s3.setFeedReminderEnabled(true);
      await s3.importData(legacy);
      expect(s3.feedReminderEnabled, isTrue);

      final s4 = await _freshState();
      await s4.importData(legacy);
      expect(s4.feedReminderEnabled, isFalse);

      s.dispose();
      s2.dispose();
      s3.dispose();
      s4.dispose();
    });
  });
}
