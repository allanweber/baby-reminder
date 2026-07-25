import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baby_feed_tracker/models/diaper.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('diaper model', () {
    test('detail string spans pee, poop color and amount', () {
      const both = Diaper(
        id: 'x',
        date: '2026-07-25',
        time: '14:10',
        type: DiaperType.both,
        peeColor: PeeColor.pale,
        poopColor: PoopColor.brown,
        poopAmount: 'Medium',
      );
      expect(both.detailStr, 'Pee · Pale yellow  ·  Poop · Brown · Medium');
      expect(both.hasPee, isTrue);
      expect(both.hasPoop, isTrue);

      const peeOnly = Diaper(id: 'y', date: '2026-07-25', time: '08:00', type: DiaperType.pee, peeColor: PeeColor.yellow);
      expect(peeOnly.detailStr, 'Pee · Yellow');
      expect(peeOnly.hasPoop, isFalse);
    });

    test('round-trips through JSON including null colors', () {
      const d = Diaper(id: 'z', date: '2026-07-25', time: '07:15', type: DiaperType.poop, poopColor: PoopColor.yellow, poopAmount: 'Small', note: 'ok');
      final back = Diaper.fromJson(d.toJson());
      expect(back.type, DiaperType.poop);
      expect(back.peeColor, isNull);
      expect(back.poopColor, PoopColor.yellow);
      expect(back.poopAmount, 'Small');
      expect(back.note, 'ok');
    });
  });

  group('diaper state', () {
    test('saving a diaper adds it and it can be deleted', () async {
      final s = await _loadedState();
      final before = s.diapers.length;
      final d = Diaper(id: s.newDiaperId(), date: '2026-07-25', time: '12:00', type: DiaperType.pee, peeColor: PeeColor.clear);
      await s.saveDiaper(d, isNew: true);
      expect(s.diapers.length, before + 1);
      await s.deleteDiaper(d.id);
      expect(s.diapers.length, before);
      s.dispose();
    });

    test('stats count a "both" change toward both pee and poop', () async {
      final s = await _loadedState();
      final list = [
        const Diaper(id: 'a', date: '2026-07-25', time: '08:00', type: DiaperType.pee, peeColor: PeeColor.yellow),
        const Diaper(id: 'b', date: '2026-07-25', time: '10:00', type: DiaperType.poop, poopColor: PoopColor.brown),
        const Diaper(id: 'c', date: '2026-07-25', time: '12:00', type: DiaperType.both, peeColor: PeeColor.pale, poopColor: PoopColor.green),
      ];
      final stats = s.diaperStatsFor(list);
      expect(stats.total, 3);
      expect(stats.peeCount, 2); // pee + both
      expect(stats.poopCount, 2); // poop + both
      s.dispose();
    });

    test('backup round-trips diapers', () async {
      final s = await _loadedState();
      final d = Diaper(id: s.newDiaperId(), date: '2026-07-25', time: '15:30', type: DiaperType.both, peeColor: PeeColor.dark, poopColor: PoopColor.red, poopAmount: 'Large');
      await s.saveDiaper(d, isNew: true);
      final json = s.exportData();

      final s2 = await _loadedState();
      final ok = await s2.importData(json);
      expect(ok, isNotNull);
      final restored = s2.diapers.firstWhere((x) => x.id == d.id);
      expect(restored.type, DiaperType.both);
      expect(restored.peeColor, PeeColor.dark);
      expect(restored.poopColor, PoopColor.red);
      expect(restored.poopAmount, 'Large');
      s.dispose();
      s2.dispose();
    });

    test('restoring an old backup without a diapers key leaves diapers intact', () async {
      final s = await _loadedState();
      const oldBackup = '{"app":"baby_feed_tracker","version":2,"feeds":[],"babyName":"Mia","reminders":[]}';
      final before = s.diapers.length;
      final ok = await s.importData(oldBackup);
      expect(ok, isNotNull);
      expect(s.babyName, 'Mia');
      // Seed diapers survive because the backup didn't carry a diapers key.
      expect(s.diapers.length, before);
      s.dispose();
    });
  });
}
