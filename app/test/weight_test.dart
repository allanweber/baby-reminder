import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baby_feed_tracker/models/weight.dart';
import 'package:baby_feed_tracker/services/alarm_service.dart';
import 'package:baby_feed_tracker/services/notification_service.dart';
import 'package:baby_feed_tracker/services/storage_service.dart';
import 'package:baby_feed_tracker/state/app_state.dart';

Future<AppState> _loadedState() async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.create();
  final appState = AppState(storage, NotificationService(), AlarmService());
  await appState.load();
  return appState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('weight model', () {
    test('round-trips through JSON', () {
      const w = Weight(id: 'x', date: '2026-07-25', kg: 4.55);
      final back = Weight.fromJson(w.toJson());
      expect(back.id, 'x');
      expect(back.date, '2026-07-25');
      expect(back.kg, 4.55);
    });
  });

  group('weight state', () {
    test('saving a weigh-in adds it and it can be deleted', () async {
      final s = await _loadedState();
      final before = s.weights.length;
      final w = Weight(id: s.newWeightId(), date: '2026-07-25', kg: 5.0);
      await s.saveWeight(w, isNew: true);
      expect(s.weights.length, before + 1);
      await s.deleteWeight(w.id);
      expect(s.weights.length, before);
      s.dispose();
    });

    test('latest weight is the chronologically newest entry', () async {
      final s = await _loadedState();
      s.weights = [
        const Weight(id: 'a', date: '2026-06-01', kg: 3.0),
        const Weight(id: 'b', date: '2026-07-01', kg: 4.0),
        const Weight(id: 'c', date: '2026-05-01', kg: 2.5),
      ];
      expect(s.latestWeight!.id, 'b');
      expect(s.latestWeight!.kg, 4.0);
      s.dispose();
    });

    test('delta is the change since the previous entry, null for the first', () async {
      final s = await _loadedState();
      s.weights = [
        const Weight(id: 'a', date: '2026-06-01', kg: 3.60),
        const Weight(id: 'b', date: '2026-06-15', kg: 4.05),
      ];
      final asc = s.weightsAscending;
      expect(s.weightDeltaKg(asc[0]), isNull); // earliest — nothing to compare
      expect(s.weightDeltaKg(asc[1]), closeTo(0.45, 1e-9));
      s.dispose();
    });

    test('labels format to exactly 2 decimals in kg and lb', () async {
      final s = await _loadedState();
      await s.setWeightUnitPref('kg');
      expect(s.weightLabel(4.5), '4.50 kg');
      expect(s.weightDeltaLabel(0.4), '+0.40 kg');
      expect(s.weightDeltaLabel(-0.1), '-0.10 kg');

      await s.setWeightUnitPref('lb');
      // 4.5 kg = 9.9208… lb → "9.92 lb"
      expect(s.weightLabel(4.5), '9.92 lb');
      // +0.45 kg ≈ +0.99 lb
      expect(s.weightDeltaLabel(0.45), '+0.99 lb');
      s.dispose();
    });

    test('backup round-trips weights and the unit preference', () async {
      final s = await _loadedState();
      await s.setWeightUnitPref('lb');
      final w = Weight(id: s.newWeightId(), date: '2026-07-25', kg: 5.25);
      await s.saveWeight(w, isNew: true);
      final json = s.exportData();

      final s2 = await _loadedState();
      final ok = await s2.importData(json);
      expect(ok, isNotNull);
      expect(s2.weightUnitPref, 'lb');
      final restored = s2.weights.firstWhere((x) => x.id == w.id);
      expect(restored.kg, 5.25);
      expect(restored.date, '2026-07-25');
      s.dispose();
      s2.dispose();
    });

    test('restoring an old backup without a weights key leaves weights intact', () async {
      final s = await _loadedState();
      // Log a weigh-in, then restore a backup that carries no weights key.
      final w = Weight(id: s.newWeightId(), date: '2026-07-25', kg: 4.0);
      await s.saveWeight(w, isNew: true);
      const oldBackup = '{"app":"baby_feed_tracker","version":2,"feeds":[],"babyName":"Mia","reminders":[]}';
      final before = s.weights.length;
      final ok = await s.importData(oldBackup);
      expect(ok, isNotNull);
      expect(s.babyName, 'Mia');
      // The existing weigh-in survives because the backup didn't carry a weights key.
      expect(s.weights.length, before);
      s.dispose();
    });
  });
}
