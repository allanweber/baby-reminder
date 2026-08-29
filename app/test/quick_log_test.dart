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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderLog quick-log model', () {
    test('a null reminderId marks it as a quick log; a real id does not', () {
      const quick = ReminderLog(id: 'a', reminderId: null, label: 'Bath', category: ReminderCategory.bath, date: '2026-07-25', time: '10:00');
      const scheduled = ReminderLog(id: 'b', reminderId: 'r1', label: 'Vitamin D', category: ReminderCategory.vitamins, date: '2026-07-25', time: '09:00');
      expect(quick.isQuickLog, isTrue);
      expect(scheduled.isQuickLog, isFalse);
    });

    test('JSON round-trips a null reminderId as a quick log', () {
      const quick = ReminderLog(id: 'a', reminderId: null, label: 'Bath', category: ReminderCategory.bath, date: '2026-07-25', time: '10:00');
      final back = ReminderLog.fromJson(quick.toJson());
      expect(back.reminderId, isNull);
      expect(back.isQuickLog, isTrue);
      // A legacy log that stored an empty string also reads back as a quick log.
      final legacy = ReminderLog.fromJson({'id': 'x', 'reminderId': '', 'label': 'Bath', 'category': 'bath', 'date': '2026-07-25', 'time': '10:00'});
      expect(legacy.isQuickLog, isTrue);
    });

    test('a note round-trips through JSON', () {
      const withNote = ReminderLog(id: 'a', reminderId: null, label: 'Medication', category: ReminderCategory.medicine, date: '2026-07-25', time: '10:00', note: 'Paracetamol 2.5ml');
      final back = ReminderLog.fromJson(withNote.toJson());
      expect(back.note, 'Paracetamol 2.5ml');
    });

    test('a log with no note omits the key and decodes as null', () {
      const noNote = ReminderLog(id: 'a', reminderId: null, label: 'Bath', category: ReminderCategory.bath, date: '2026-07-25', time: '10:00');
      expect(noNote.toJson().containsKey('note'), isFalse);
      // An older backup without a note key still loads (note stays null).
      final legacy = ReminderLog.fromJson({'id': 'x', 'reminderId': null, 'label': 'Bath', 'category': 'bath', 'date': '2026-07-25', 'time': '10:00'});
      expect(legacy.note, isNull);
    });

    test('copyWith leaves the note untouched unless explicitly changed', () {
      const original = ReminderLog(id: 'a', reminderId: null, label: 'Other', category: ReminderCategory.other, date: '2026-07-25', time: '10:00', note: 'kept');
      // Editing only date/time keeps the note.
      expect(original.copyWith(time: '11:00').note, 'kept');
      // Passing a new note replaces it; passing null clears it.
      expect(original.copyWith(note: 'changed').note, 'changed');
      expect(original.copyWith(note: null).note, isNull);
    });
  });

  group('quick log state', () {
    test('quickLog appends an ad-hoc log dated today with the current time', () async {
      final s = await _loadedState();
      final before = s.reminderLogs.length;
      final log = await s.quickLog(ReminderCategory.medicine);
      expect(s.reminderLogs.length, before + 1);
      expect(log.reminderId, isNull);
      expect(log.label, reminderCategories[ReminderCategory.medicine]!.label);
      expect(log.date, dateStr(DateTime.now()));
      s.dispose();
    });

    test('report splits scheduled completions (Completed) from quick logs (Logged)', () async {
      final s = await _loadedState();
      final today = dateStr(DateTime.now());
      final completedBefore = s.completedLogsForDate(today).length;
      final loggedBefore = s.quickLogsForDate(today).length;

      await s.quickLog(ReminderCategory.vitamins);

      expect(s.quickLogsForDate(today).length, loggedBefore + 1);
      // A quick log must not inflate the scheduled-completion count.
      expect(s.completedLogsForDate(today).length, completedBefore);
      s.dispose();
    });

    test('editing a quick log changes its date/time', () async {
      final s = await _loadedState();
      final log = await s.quickLog(ReminderCategory.bath);
      await s.updateReminderLog(log.id, date: '2026-07-20', time: '08:30');
      final after = s.reminderLogs.firstWhere((l) => l.id == log.id);
      expect(after.date, '2026-07-20');
      expect(after.time, '08:30');
      expect(after.isQuickLog, isTrue);
      s.dispose();
    });

    test('editing a quick log adds, keeps and clears a note', () async {
      final s = await _loadedState();
      final log = await s.quickLog(ReminderCategory.medicine);

      await s.updateReminderLog(log.id, date: log.date, time: log.time, note: 'Ibuprofen 3ml');
      expect(s.reminderLogs.firstWhere((l) => l.id == log.id).note, 'Ibuprofen 3ml');

      // Omitting `note` on a later edit leaves it in place.
      await s.updateReminderLog(log.id, date: '2026-07-20', time: log.time);
      expect(s.reminderLogs.firstWhere((l) => l.id == log.id).note, 'Ibuprofen 3ml');

      // Passing null clears it.
      await s.updateReminderLog(log.id, date: log.date, time: log.time, note: null);
      expect(s.reminderLogs.firstWhere((l) => l.id == log.id).note, isNull);
      s.dispose();
    });

    test('deleting a quick log removes it', () async {
      final s = await _loadedState();
      final log = await s.quickLog(ReminderCategory.other);
      final before = s.reminderLogs.length;
      await s.deleteReminderLog(log.id);
      expect(s.reminderLogs.length, before - 1);
      expect(s.reminderLogs.any((l) => l.id == log.id), isFalse);
      s.dispose();
    });

    test('quick logs survive a backup round-trip', () async {
      final s = await _loadedState();
      final log = await s.quickLog(ReminderCategory.exercises);
      final json = s.exportData();

      final s2 = await _loadedState();
      final ok = await s2.importData(json);
      expect(ok, isNotNull);
      final restored = s2.reminderLogs.firstWhere((l) => l.id == log.id);
      expect(restored.isQuickLog, isTrue);
      expect(restored.category, ReminderCategory.exercises);
      s.dispose();
      s2.dispose();
    });
  });
}
