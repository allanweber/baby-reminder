import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baby_feed_tracker/models/feed.dart';
import 'package:baby_feed_tracker/services/alarm_service.dart';
import 'package:baby_feed_tracker/services/notification_service.dart';
import 'package:baby_feed_tracker/services/storage_service.dart';
import 'package:baby_feed_tracker/state/app_state.dart';
import 'package:baby_feed_tracker/theme/app_theme.dart';

Future<AppState> _loadedState() async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.create();
  final appState = AppState(storage, NotificationService(), AlarmService());
  await appState.load();
  return appState;
}

Feed _feed(AppState s, {List<String> tags = const []}) => Feed(
      id: s.newFeedId(),
      date: dateStr(DateTime.now()),
      time: timeStr(DateTime.now()),
      type: FeedType.formula,
      amountMl: 120,
      durationMin: 0,
      note: '',
      tags: tags,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('feed tags', () {
    test('a feed carries its tags through JSON', () {
      const f = Feed(
        id: 'f1', date: '2026-08-06', time: '10:00', type: FeedType.formula,
        amountMl: 120, durationMin: 0, note: '', tags: ['Fussy', 'Spit up'],
      );
      final round = Feed.fromJson(f.toJson());
      expect(round.tags, ['Fussy', 'Spit up']);
    });

    test('an older feed JSON with no tags key loads as untagged', () {
      final round = Feed.fromJson({
        'id': 'f1', 'date': '2026-08-06', 'time': '10:00', 'type': 'formula',
        'amountMl': 120, 'durationMin': 0, 'note': '',
      });
      expect(round.tags, isEmpty);
    });

    test('saving a feed remembers its new tags in the reusable vocabulary', () async {
      final s = await _loadedState();
      await s.saveFeed(_feed(s, tags: ['Reflux', 'Cluster feed']), isNew: true);
      expect(s.feedTags.contains('Reflux'), isTrue);
      expect(s.feedTags.contains('Cluster feed'), isTrue);
      s.dispose();
    });

    test('an already-known tag is not duplicated (case-insensitive)', () async {
      final s = await _loadedState();
      final before = s.feedTags.length;
      // 'Fussy' is a seeded tag; re-adding it (different case) must not grow the list.
      await s.saveFeed(_feed(s, tags: ['fussy']), isNew: true);
      expect(s.feedTags.length, before);
      s.dispose();
    });

    test('remembered tags survive a reload', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.create();
      final s1 = AppState(storage, NotificationService(), AlarmService());
      await s1.load();
      await s1.saveFeed(_feed(s1, tags: ['Overnight']), isNew: true);
      s1.dispose();

      // A second AppState over the same storage sees the saved vocabulary.
      final s2 = AppState(storage, NotificationService(), AlarmService());
      await s2.load();
      expect(s2.feedTags.contains('Overnight'), isTrue);
      s2.dispose();
    });

    test('backup round-trips feed tags and the vocabulary', () async {
      final s = await _loadedState();
      await s.saveFeed(_feed(s, tags: ['Windy']), isNew: true);
      final json = s.exportData();

      final s2 = await _loadedState();
      final ok = await s2.importData(json);
      expect(ok, isNotNull);
      expect(s2.feeds.any((f) => f.tags.contains('Windy')), isTrue);
      expect(s2.feedTags.contains('Windy'), isTrue);
      s.dispose();
      s2.dispose();
    });

    test('importing an old backup repopulates the vocabulary from feed tags', () async {
      final s = await _loadedState();
      // A v4-style backup: feeds carry tags but there is no feedTags key.
      const oldBackup =
          '{"app":"baby_feed_tracker","version":4,"feeds":['
          '{"id":"f1","date":"2026-08-01","time":"08:00","type":"formula",'
          '"amountMl":120,"durationMin":0,"note":"","tags":["Legacy tag"]}]}';
      final ok = await s.importData(oldBackup);
      expect(ok, isNotNull);
      expect(s.feedTags.contains('Legacy tag'), isTrue);
      s.dispose();
    });
  });
}
