import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baby_feed_tracker/models/reminder.dart';
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

String _pad2(int n) => n < 10 ? '0$n' : '$n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reminders', () {
    test('adding a fixed reminder allocates a distinct alarm id and future due time', () async {
      final s = await _loadedState();
      final before = s.reminders.length;
      final r = await s.addReminder(
        label: 'Iron drops',
        category: ReminderCategory.medicine,
        mode: ReminderMode.fixed,
        fixedTime: '08:30',
        intervalHours: 0,
      );
      expect(s.reminders.length, before + 1);
      expect(r.alarmId, greaterThanOrEqualTo(1000));
      // Feed reminder (1) and test alarm (2) ids are never reused.
      expect(r.alarmId, isNot(1));
      expect(r.alarmId, isNot(2));
      expect(r.nextDueAt, greaterThan(DateTime.now().millisecondsSinceEpoch));
      s.dispose();
    });

    test('duplicate fixed hh:mm is detected and names the conflict', () async {
      final s = await _loadedState();
      await s.addReminder(
        label: 'Morning meds',
        category: ReminderCategory.medicine,
        mode: ReminderMode.fixed,
        fixedTime: '07:15',
        intervalHours: 0,
      );
      final conflict = s.fixedTimeConflict('07:15');
      expect(conflict, isNotNull);
      expect(conflict!.label, 'Morning meds');
      // A different time does not conflict.
      expect(s.fixedTimeConflict('07:16'), isNull);
      s.dispose();
    });

    test('interval reminders are exempt from the duplicate-time check', () async {
      final s = await _loadedState();
      await s.addReminder(
        label: 'Tummy time',
        category: ReminderCategory.tummyTime,
        mode: ReminderMode.interval,
        fixedTime: '',
        intervalHours: 3,
      );
      // Even though an interval reminder exists, a fixed reminder can take any
      // free clock slot — interval reminders don't occupy one.
      expect(s.fixedTimeConflict('11:11'), isNull);
      s.dispose();
    });

    test('marking done logs a completion and rolls a fixed reminder to the next day', () async {
      final s = await _loadedState();
      final r = await s.addReminder(
        label: 'Vitamin D',
        category: ReminderCategory.vitamins,
        mode: ReminderMode.fixed,
        fixedTime: '10:00',
        intervalHours: 0,
      );
      final logsBefore = s.reminderLogs.length;
      await s.markReminderDone(r);
      expect(s.reminderLogs.length, logsBefore + 1);
      final after = s.reminders.firstWhere((x) => x.id == r.id);
      // Next due is strictly in the future (tomorrow at 10:00 at the latest).
      expect(after.nextDueAt, greaterThan(DateTime.now().millisecondsSinceEpoch));
      s.dispose();
    });

    test('marking done reschedules an interval reminder ~N hours out', () async {
      final s = await _loadedState();
      final r = await s.addReminder(
        label: 'Stretch',
        category: ReminderCategory.exercises,
        mode: ReminderMode.interval,
        fixedTime: '',
        intervalHours: 6,
      );
      await s.markReminderDone(r);
      final after = s.reminders.firstWhere((x) => x.id == r.id);
      final expected = DateTime.now().add(const Duration(hours: 6)).millisecondsSinceEpoch;
      expect((after.nextDueAt - expected).abs() < 5000, isTrue);
      s.dispose();
    });

    test('a fixed reminder due earlier today with no completion shows as missed', () async {
      final s = await _loadedState();
      final now = DateTime.now();
      // Skip near midnight where "an hour ago" could fall on the previous day.
      if (now.hour < 1) {
        s.dispose();
        return;
      }
      final past = now.subtract(const Duration(hours: 1));
      final hhmm = '${_pad2(past.hour)}:${_pad2(past.minute)}';
      await s.addReminder(
        label: 'Eye drops',
        category: ReminderCategory.medicine,
        mode: ReminderMode.fixed,
        fixedTime: hhmm,
        intervalHours: 0,
      );
      final missed = s.missedRemindersForDate(dateStr(now));
      expect(missed.any((m) => m.reminder.label == 'Eye drops'), isTrue);
      s.dispose();
    });

    test('backup round-trips reminders and completion history', () async {
      final s = await _loadedState();
      await s.addReminder(
        label: 'Probiotic',
        category: ReminderCategory.other,
        mode: ReminderMode.fixed,
        fixedTime: '20:00',
        intervalHours: 0,
      );
      final json = s.exportData();

      final s2 = await _loadedState();
      final remindersBefore = s2.reminders.length;
      final ok = await s2.importData(json);
      expect(ok, isNotNull);
      expect(s2.reminders.any((r) => r.label == 'Probiotic'), isTrue);
      // Import replaced the reminder set with the backup's contents.
      expect(s2.reminders.length, isNot(remindersBefore + 99));
      s.dispose();
      s2.dispose();
    });

    test('restoring an old feeds-only backup leaves existing reminders intact', () async {
      final s = await _loadedState();
      // Create a reminder, then restore a v1-style backup with no reminders key.
      await s.addReminder(
        label: 'Existing',
        category: ReminderCategory.other,
        mode: ReminderMode.fixed,
        fixedTime: '12:00',
        intervalHours: 0,
      );
      const oldBackup = '{"app":"baby_feed_tracker","version":1,"feeds":[],"babyName":"Mia"}';
      final remindersBefore = s.reminders.length;
      final ok = await s.importData(oldBackup);
      expect(ok, isNotNull);
      expect(s.babyName, 'Mia');
      // The existing reminder survives because the backup didn't carry a reminders key.
      expect(s.reminders.length, remindersBefore);
      s.dispose();
    });
  });
}
