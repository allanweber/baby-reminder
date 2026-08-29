import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baby_feed_tracker/services/alarm_service.dart';
import 'package:baby_feed_tracker/services/notification_service.dart';
import 'package:baby_feed_tracker/services/storage_service.dart';
import 'package:baby_feed_tracker/state/app_state.dart';
import 'package:baby_feed_tracker/widgets/log_feed_sheet.dart';

Future<AppState> _loadedState() async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.create();
  final appState = AppState(storage, NotificationService(), AlarmService());
  await appState.load();
  return appState;
}

void main() {
  testWidgets('feed duration can be typed directly and clamps to a sensible max',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final appState = await _loadedState();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LogFeedSheet(appState: appState)),
    ));
    await tester.pump();

    // A fresh feed starts at 0 minutes.
    expect(find.text('0 m'), findsOneWidget);

    // Tapping the value opens the direct-entry dialog: a long feed is one type,
    // not forty taps.
    await tester.tap(find.text('0 m'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '40');
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
    expect(find.text('40 m'), findsOneWidget);

    // An out-of-range value is clamped to the upper bound rather than stored raw.
    await tester.tap(find.text('40 m'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '999');
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
    expect(find.text('240 m'), findsOneWidget);

    // Dispose inside the body so AppState's periodic ticker is cancelled before
    // the framework's pending-timer check runs.
    appState.dispose();
  });

  testWidgets('the +/- buttons step the feed duration by 5 minutes',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final appState = await _loadedState();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LogFeedSheet(appState: appState)),
    ));
    await tester.pump();

    // Switch to breastfeeding so the amount stepper is hidden and the only
    // +/- buttons on screen are the duration ones.
    await tester.tap(find.text('Breastfeeding'));
    await tester.pump();
    expect(find.text('0 m'), findsOneWidget);

    await tester.tap(find.text('+'));
    await tester.pump();
    expect(find.text('5 m'), findsOneWidget);

    await tester.tap(find.text('+'));
    await tester.pump();
    expect(find.text('10 m'), findsOneWidget);

    await tester.tap(find.text('–'));
    await tester.pump();
    expect(find.text('5 m'), findsOneWidget);

    appState.dispose();
  });
}
