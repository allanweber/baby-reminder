// Portfolio screenshot harness.
//
// Renders the real app screens (via the production widgets, theme and fonts)
// on a fixed seed of sample data and writes PNGs to build/shots/. It is a
// widget test only so it can drive the Flutter render pipeline headlessly — it
// asserts nothing. Run it explicitly (it lives outside test/ so `flutter test`
// in CI never picks it up):
//
//   flutter test tool/portfolio_shots.dart
//
// Review build/shots/, then copy the ones you want into portfolio/images/.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baby_feed_tracker/main.dart';
import 'package:baby_feed_tracker/models/appointment.dart';
import 'package:baby_feed_tracker/models/diaper.dart';
import 'package:baby_feed_tracker/models/feed.dart';
import 'package:baby_feed_tracker/models/reminder.dart';
import 'package:baby_feed_tracker/models/weight.dart';
import 'package:baby_feed_tracker/services/alarm_service.dart';
import 'package:baby_feed_tracker/services/notification_service.dart';
import 'package:baby_feed_tracker/services/storage_service.dart';
import 'package:baby_feed_tracker/state/app_state.dart';
import 'package:baby_feed_tracker/theme/app_theme.dart';
import 'package:baby_feed_tracker/widgets/feed_fab.dart';

const double _w = 390;
const double _h = 860;
const double _dpr = 3.0;
final _rootKey = GlobalKey();
const _outDir = 'build/shots';

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final loader = FontLoader(family)
      ..addFont(Future.value(File(path).readAsBytesSync().buffer.asByteData()));
    await loader.load();
  }

  await load('Baloo 2', 'assets/fonts/Baloo2.ttf');
  await load('Nunito', 'assets/fonts/Nunito.ttf');
  await load('Nunito', 'assets/fonts/Nunito-Italic.ttf');
}

/// Builds a seeded [AppState] without calling load() (so no ticker/timers run),
/// mirroring the sample data the original portfolio shots used. Synchronous and
/// reusing a single [storage] on purpose: constructing SharedPreferences per
/// shot hangs the second time under the test's fake-async, and nothing here
/// persists (fields are set directly), so the shared store is never read.
AppState _seed(StorageService storage, {bool dark = false}) {
  final s = AppState(storage, NotificationService(), AlarmService());

  final nowDt = DateTime.now();
  final t3 = nowDt.subtract(const Duration(minutes: 40));
  final yest = nowDt.subtract(const Duration(days: 1));
  final createdMs = nowDt.millisecondsSinceEpoch;

  s.babyName = 'Isabel';
  s.unitPref = 'ml';
  s.weightUnitPref = 'kg';
  s.darkMode = dark;
  s.feedReminderEnabled = true;
  s.reminderIntervalMin = 180;
  s.nextReminderAt = t3.add(const Duration(minutes: 180)).millisecondsSinceEpoch;
  s.reminderDismissed = false;

  s.feeds = [
    Feed(id: 'y1', date: dateStr(yest), time: '07:00', type: FeedType.formula, amountMl: 110, durationMin: 0, note: ''),
    Feed(id: 'y2', date: dateStr(yest), time: '10:15', type: FeedType.breastfeeding, amountMl: 0, durationMin: 18, note: ''),
    Feed(id: 'y3', date: dateStr(yest), time: '13:30', type: FeedType.formula, amountMl: 120, durationMin: 0, note: ''),
    Feed(id: 'y4', date: dateStr(yest), time: '16:45', type: FeedType.breastBottle, amountMl: 100, durationMin: 0, note: ''),
    Feed(id: 'y5', date: dateStr(yest), time: '19:50', type: FeedType.formula, amountMl: 130, durationMin: 20, note: 'Settled quickly after', tags: ['Sleepy']),
    Feed(id: 't1', date: dateStr(nowDt), time: '06:30', type: FeedType.formula, amountMl: 120, durationMin: 0, note: ''),
    Feed(id: 't2', date: dateStr(nowDt), time: '09:45', type: FeedType.breastBottle, amountMl: 100, durationMin: 0, note: '', tags: ['Good latch']),
    Feed(id: 't3', date: dateStr(t3), time: timeStr(t3), type: FeedType.formula, amountMl: 130, durationMin: 22, note: 'Fussy, took a bit longer', tags: ['Fussy', 'Spit up']),
  ]..sort((a, b) => a.sortKey.compareTo(b.sortKey));
  s.feedTags = ['Fussy', 'Spit up', 'Sleepy', 'Good latch', 'Gassy'];

  s.reminders = [
    Reminder(
      id: 'r1', alarmId: 1000, label: 'Vitamin D drops', category: ReminderCategory.vitamins,
      mode: ReminderMode.fixed, fixedTime: '09:00', intervalHours: 0,
      nextDueAt: Reminder.nextFixedOccurrence('09:00', nowDt).millisecondsSinceEpoch, createdAt: createdMs,
    ),
    Reminder(
      id: 'r2', alarmId: 1001, label: 'Tummy time', category: ReminderCategory.tummyTime,
      mode: ReminderMode.interval, fixedTime: '', intervalHours: 4,
      nextDueAt: nowDt.add(const Duration(hours: 4)).millisecondsSinceEpoch, createdAt: createdMs,
    ),
  ];
  s.reminderLogs = [
    ReminderLog(id: 'rl1', reminderId: 'r1', label: 'Vitamin D drops', category: ReminderCategory.vitamins, date: dateStr(nowDt), time: '09:00'),
  ];

  final apptAt = DateTime(nowDt.year, nowDt.month, nowDt.day, 10, 30).add(const Duration(days: 3));
  s.appointments = [
    Appointment(
      id: 'a1', leadAlarmId: 1002, atAlarmId: 1003, title: '4-month checkup',
      category: AppointmentCategory.checkup, atMs: apptAt.millisecondsSinceEpoch,
      lead: AppointmentLead.oneDay, description: 'Bring the vaccination booklet.', doneAtMs: null, createdAt: createdMs,
    ),
  ];

  s.diapers = [
    Diaper(id: 'd1', date: dateStr(yest), time: '08:20', type: DiaperType.pee, peeColor: PeeColor.yellow),
    Diaper(id: 'd2', date: dateStr(yest), time: '14:10', type: DiaperType.both, peeColor: PeeColor.pale, poopColor: PoopColor.brown, poopAmount: 'Medium'),
    Diaper(id: 'd3', date: dateStr(nowDt), time: '07:15', type: DiaperType.poop, poopColor: PoopColor.yellow, poopAmount: 'Small'),
  ]..sort((a, b) => a.sortKey.compareTo(b.sortKey));

  final w1 = nowDt.subtract(const Duration(days: 28));
  final w2 = nowDt.subtract(const Duration(days: 14));
  final w3 = nowDt.subtract(const Duration(days: 3));
  s.weights = [
    Weight(id: 'w1', date: dateStr(w1), kg: 3.60),
    Weight(id: 'w2', date: dateStr(w2), kg: 4.05),
    Weight(id: 'w3', date: dateStr(w3), kg: 4.50),
  ];

  // Ensure the palette matches the requested brightness before the tree builds.
  applyPalette(dark: dark);
  return s;
}

/// Horizontal centre (logical px) of bottom-nav tab [i] of 5, with the shell's
/// 16px side padding.
double _tabX(int i) => 16 + (_w - 32) / 5 * (i + 0.5);
const double _tabY = _h - 34;

Future<void> _save(WidgetTester t, String name) async {
  final boundary = _rootKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  // Image capture is real (non-fake) async — it must run inside runAsync or it
  // hangs / trips the test's async guard.
  final bytes = await t.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: _dpr);
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final file = File('$_outDir/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
  // ignore: avoid_print
  print('wrote $_outDir/$name.png');
}

// Fixed-frame settle: pumpAndSettle can hang on repeating animations, and every
// transition here (tab switch, sheet slide-in, scroll) resolves well under a
// second, so a handful of fixed pumps is enough and never hangs.
Future<void> _settle(WidgetTester t, [int frames = 9]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 90));
  }
}

Future<void> _tapTab(WidgetTester t, int i) async {
  await t.tapAt(Offset(_tabX(i), _tabY));
  await _settle(t);
}

Future<void> _openAppointments(WidgetTester t) async {
  await _tapTab(t, 0);
  await t.tap(find.text('Appointments'));
  await _settle(t);
}

Future<void> _tapFab(WidgetTester t) async {
  await t.tap(find.byType(FeedFab));
  await _settle(t);
}

Future<void> _dragUp(WidgetTester t, double dy) async {
  await t.drag(find.byType(Scrollable).last, Offset(0, -dy));
  await _settle(t);
}

/// One clean [testWidgets] per shot so nothing carries over between renders
/// (reconstructing SharedPreferences inside a single test hangs the fake-async).
void _shot(String name, {bool dark = false, Future<void> Function(WidgetTester)? nav}) {
  testWidgets(name, (WidgetTester t) async {
    await _loadFonts();
    await t.binding.setSurfaceSize(const Size(_w, _h));
    SharedPreferences.setMockInitialValues({});
    final storage = (await t.runAsync(() => StorageService.create()))!;

    final appState = _seed(storage, dark: dark);
    await t.pumpWidget(RepaintBoundary(key: _rootKey, child: BabyFeedTrackerApp(appState: appState)));
    await _settle(t);
    if (nav != null) await nav(t);
    await _settle(t);
    await _save(t, name);

    // Consume any framework exception recorded while rendering (e.g. a
    // debug-only assertion in a sheet). The capture above already succeeded, so
    // don't let it fail the shot — surface it as a note instead.
    final Object? ex = t.takeException();
    if (ex != null) {
      // ignore: avoid_print
      print('note: $name recorded a non-fatal exception: $ex');
    }
    await t.binding.setSurfaceSize(null);
  });
}

void main() {
  // Full-screen tab views.
  _shot('10-report'); // Home (daily report) — the centred default landing (tab 2)
  _shot('01-feed-home', nav: (t) => _tapTab(t, 3)); // Feed
  _shot('09-weight', nav: (t) => _tapTab(t, 1));
  _shot('07-diapers', nav: (t) => _tapTab(t, 4));
  _shot('03-reminders', nav: (t) => _tapTab(t, 0));
  _shot('04-appointments-list', nav: _openAppointments);
  _shot('05-appointments-calendar', nav: (t) async {
    await _openAppointments(t);
    await t.tap(find.byIcon(Icons.calendar_month_rounded));
    await _settle(t);
  });

  // Modal sheets.
  _shot('02-log-feed-tags', nav: (t) async {
    await _tapTab(t, 3);
    await _tapFab(t);
    await _dragUp(t, 480); // reveal the tag chips + Cancel/Save
  });
  _shot('08-log-diaper', nav: (t) async {
    await _tapTab(t, 4);
    await _tapFab(t);
  });
  _shot('06-add-appointment', nav: (t) async {
    await _openAppointments(t);
    await _tapFab(t); // the sheet already shows through to the description field
  });
  _shot('11-settings', nav: (t) async {
    await _tapTab(t, 3);
    await t.tap(find.byTooltip('Settings'));
    await _settle(t);
  });

  // Dark mode.
  _shot('12-feed-home-dark', dark: true, nav: (t) => _tapTab(t, 3));
  _shot('13-appointments-dark', dark: true, nav: _openAppointments);
}
