import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baby_feed_tracker/models/appointment.dart';
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

  group('appointments', () {
    test('adding one allocates two distinct alarm ids and a future time', () async {
      final s = await _loadedState();
      final at = DateTime.now().add(const Duration(days: 2));
      final a = await s.addAppointment(
        title: '6-month checkup',
        category: AppointmentCategory.checkup,
        atMs: at.millisecondsSinceEpoch,
        lead: AppointmentLead.oneDay,
        description: 'bring booklet',
      );
      expect(a.leadAlarmId, isNot(a.atAlarmId));
      expect(a.leadAlarmId, greaterThanOrEqualTo(1000));
      expect(a.atAlarmId, greaterThanOrEqualTo(1000));
      // Never reuse the feed reminder (1) or test alarm (2) ids.
      expect(a.leadAlarmId, isNot(1));
      expect(a.atAlarmId, isNot(2));
      expect(a.atMs, greaterThan(DateTime.now().millisecondsSinceEpoch));
      expect(a.isDone, isFalse);
      s.dispose();
    });

    test('lead-time helpers compute the right heads-up moment', () async {
      final at = DateTime(2030, 6, 1, 10, 0);
      final oneHour = Appointment(
        id: 'x', leadAlarmId: 1, atAlarmId: 2, title: '', category: AppointmentCategory.doctor,
        atMs: at.millisecondsSinceEpoch, lead: AppointmentLead.oneHour, description: '', doneAtMs: null, createdAt: 0,
      );
      expect(oneHour.leadAt, DateTime(2030, 6, 1, 9, 0));
      final oneDay = oneHour.copyWith(lead: AppointmentLead.oneDay);
      expect(oneDay.leadAt, DateTime(2030, 5, 31, 10, 0));
      final none = oneHour.copyWith(lead: AppointmentLead.none);
      expect(none.leadAt, isNull);
    });

    test('displayTitle falls back to the category label when blank', () async {
      const a = Appointment(
        id: 'x', leadAlarmId: 1, atAlarmId: 2, title: '', category: AppointmentCategory.dentist,
        atMs: 0, lead: AppointmentLead.none, description: '', doneAtMs: null, createdAt: 0,
      );
      expect(a.displayTitle, 'Dentist');
      expect(a.copyWith(title: 'Filling').displayTitle, 'Filling');
    });

    test('marking done records it and surfaces it in the report for its day', () async {
      final s = await _loadedState();
      final at = DateTime.now().add(const Duration(days: 1));
      final a = await s.addAppointment(
        title: 'Vaccination',
        category: AppointmentCategory.vaccination,
        atMs: at.millisecondsSinceEpoch,
        lead: AppointmentLead.none,
        description: '',
      );
      await s.markAppointmentDone(a);
      final done = s.appointments.firstWhere((x) => x.id == a.id);
      expect(done.isDone, isTrue);
      // It no longer counts as upcoming/overdue…
      expect(s.upcomingAppointments.any((x) => x.id == a.id), isFalse);
      expect(s.overdueAppointments.any((x) => x.id == a.id), isFalse);
      // …and it shows in the report on its scheduled day.
      final report = s.doneAppointmentsForDate(done.dateStr);
      expect(report.any((x) => x.id == a.id), isTrue);
      s.dispose();
    });

    test('a past, not-done appointment is overdue, not upcoming', () async {
      final s = await _loadedState();
      // Build it in the past directly (the add sheet blocks past times, but the
      // model must classify a lapsed one correctly).
      final past = DateTime.now().subtract(const Duration(hours: 3));
      final a = Appointment(
        id: s.newAppointmentId(),
        leadAlarmId: 5000,
        atAlarmId: 5001,
        title: 'Late visit',
        category: AppointmentCategory.doctor,
        atMs: past.millisecondsSinceEpoch,
        lead: AppointmentLead.none,
        description: '',
        doneAtMs: null,
        createdAt: past.millisecondsSinceEpoch,
      );
      s.appointments = [...s.appointments, a];
      expect(s.overdueAppointments.any((x) => x.id == a.id), isTrue);
      expect(s.upcomingAppointments.any((x) => x.id == a.id), isFalse);
      s.dispose();
    });

    test('postpone moves the time forward and clears any done state', () async {
      final s = await _loadedState();
      final at = DateTime.now().add(const Duration(days: 1));
      final a = await s.addAppointment(
        title: 'Reschedule me',
        category: AppointmentCategory.specialist,
        atMs: at.millisecondsSinceEpoch,
        lead: AppointmentLead.oneHour,
        description: '',
      );
      final newAt = DateTime.now().add(const Duration(days: 5));
      await s.postponeAppointment(a, newAt);
      final after = s.appointments.firstWhere((x) => x.id == a.id);
      expect(after.isDone, isFalse);
      expect((after.atMs - newAt.millisecondsSinceEpoch).abs() < 1000, isTrue);
      s.dispose();
    });

    test('backup round-trips appointments', () async {
      final s = await _loadedState();
      final at = DateTime.now().add(const Duration(days: 2));
      await s.addAppointment(
        title: 'Eye clinic',
        category: AppointmentCategory.specialist,
        atMs: at.millisecondsSinceEpoch,
        lead: AppointmentLead.oneDay,
        description: 'dilating drops',
      );
      final json = s.exportData();

      final s2 = await _loadedState();
      final ok = await s2.importData(json);
      expect(ok, isNotNull);
      expect(s2.appointments.any((x) => x.title == 'Eye clinic'), isTrue);
      s.dispose();
      s2.dispose();
    });

    test('restoring an old backup with no appointments key leaves existing appointments intact', () async {
      final s = await _loadedState();
      // Create an appointment, then restore a backup with no appointments key.
      final at = DateTime.now().add(const Duration(days: 2));
      await s.addAppointment(
        title: 'Existing',
        category: AppointmentCategory.checkup,
        atMs: at.millisecondsSinceEpoch,
        lead: AppointmentLead.none,
        description: '',
      );
      const oldBackup = '{"app":"baby_feed_tracker","version":1,"feeds":[],"babyName":"Mia"}';
      final before = s.appointments.length;
      final ok = await s.importData(oldBackup);
      expect(ok, isNotNull);
      expect(s.babyName, 'Mia');
      // The existing appointment survives because the backup didn't carry an appointments key.
      expect(s.appointments.length, before);
      s.dispose();
    });

    test('new alarm ids stay ahead of imported appointment ids', () async {
      final s = await _loadedState();
      // A backup whose appointment uses high alarm ids.
      final backup = '{"app":"baby_feed_tracker","version":4,"feeds":[],'
          '"appointments":[{"id":"z","leadAlarmId":9000,"atAlarmId":9001,"title":"Big id",'
          '"category":"doctor","atMs":${DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch},'
          '"lead":"none","description":"","doneAtMs":null,"createdAt":0}]}';
      await s.importData(backup);
      final at = DateTime.now().add(const Duration(days: 1));
      final fresh = await s.addAppointment(
        title: 'After import',
        category: AppointmentCategory.doctor,
        atMs: at.millisecondsSinceEpoch,
        lead: AppointmentLead.none,
        description: '',
      );
      expect(fresh.leadAlarmId, greaterThan(9001));
      expect(fresh.atAlarmId, greaterThan(fresh.leadAlarmId));
      s.dispose();
    });
  });
}
