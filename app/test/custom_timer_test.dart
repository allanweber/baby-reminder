import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baby_feed_tracker/models/feed.dart';
import 'package:baby_feed_tracker/services/alarm_service.dart';
import 'package:baby_feed_tracker/services/notification_service.dart';
import 'package:baby_feed_tracker/services/storage_service.dart';
import 'package:baby_feed_tracker/state/app_state.dart';
import 'package:baby_feed_tracker/theme/app_theme.dart';

/// Builds a loaded AppState backed by a mock SharedPreferences. The real
/// NotificationService/AlarmService are used but their platform channels are
/// absent under `flutter test`; the state layer swallows those failures, so
/// the pure scheduling logic below stays exercisable without a device.
Future<AppState> _loadedState() async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.create();
  final appState = AppState(storage, NotificationService(), AlarmService());
  await appState.load();
  return appState;
}

Feed _feedAt(AppState s, DateTime when) => Feed(
      id: s.newFeedId(),
      date: dateStr(when),
      time: timeStr(when),
      type: FeedType.formula,
      amountMl: 100,
      durationMin: 0,
      note: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('custom on-demand timer', () {
    test('start overrides the feed reminder, cancel restores it', () async {
      final s = await _loadedState();
      final feedNext = s.nextReminderAt;
      expect(s.customTimerActive, isFalse);
      expect(s.effectiveReminderAt, feedNext);

      await s.startCustomTimer(const Duration(minutes: 10));
      expect(s.customTimerActive, isTrue);
      // Effective target is now the timer, ~10 minutes out (not the feed).
      final expected = DateTime.now().millisecondsSinceEpoch + 10 * 60000;
      expect((s.effectiveReminderAt - expected).abs() < 2000, isTrue);
      expect(s.effectiveReminderAt, isNot(feedNext));

      await s.cancelCustomTimer();
      expect(s.customTimerActive, isFalse);
      // The feed reminder underneath is untouched and comes back.
      expect(s.effectiveReminderAt, feedNext);

      s.dispose();
    });

    test('starting a second timer replaces the first', () async {
      final s = await _loadedState();
      await s.startCustomTimer(const Duration(minutes: 10));
      final first = s.customTimerAt!;
      await s.startCustomTimer(const Duration(minutes: 30));
      final second = s.customTimerAt!;
      expect(second, greaterThan(first));
      expect(s.customTimerActive, isTrue);
      s.dispose();
    });

    test('extend adds time to the running timer', () async {
      final s = await _loadedState();
      await s.startCustomTimer(const Duration(minutes: 10));
      final before = s.customTimerAt!;
      await s.extendCustomTimer(const Duration(minutes: 5));
      expect(s.customTimerAt! - before, 5 * 60000);
      s.dispose();
    });

    test('dismiss clears an active timer (routes to cancel)', () async {
      final s = await _loadedState();
      await s.startCustomTimer(const Duration(minutes: 10));
      expect(s.customTimerActive, isTrue);
      await s.dismissReminder();
      expect(s.customTimerActive, isFalse);
      s.dispose();
    });
  });

  group('feed reminder scheduling', () {
    test('logging a recent feed restarts the countdown', () async {
      final s = await _loadedState();
      final recent = DateTime.now().subtract(const Duration(minutes: 5));
      await s.saveFeed(_feedAt(s, recent), isNew: true);
      final expected = dtToMs(dateStr(recent), timeStr(recent)) + s.reminderIntervalMin * 60000;
      expect(s.nextReminderAt, expected);
      s.dispose();
    });

    test('back-filling an old feed does not move the reminder', () async {
      final s = await _loadedState();
      final before = s.nextReminderAt;
      // Older than the reminder interval, so its reminder would already be due:
      // treated as history, must not reschedule.
      final old = DateTime.now().subtract(Duration(minutes: s.reminderIntervalMin + 120));
      await s.saveFeed(_feedAt(s, old), isNew: true);
      expect(s.nextReminderAt, before);
      s.dispose();
    });
  });
}
