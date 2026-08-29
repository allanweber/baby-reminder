import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baby_feed_tracker/services/alarm_service.dart';
import 'package:baby_feed_tracker/services/notification_service.dart';
import 'package:baby_feed_tracker/services/storage_service.dart';
import 'package:baby_feed_tracker/state/app_state.dart';
import 'package:baby_feed_tracker/widgets/log_diaper_sheet.dart';

Future<AppState> _loadedState() async {
  SharedPreferences.setMockInitialValues({});
  final storage = await StorageService.create();
  final appState = AppState(storage, NotificationService(), AlarmService());
  await appState.load();
  return appState;
}

void main() {
  testWidgets('saving a diaper with no colour shows an inline error that clears on selection',
      (WidgetTester tester) async {
    // A tall surface so the whole sheet fits without scrolling the Save button
    // out of the hit-test area.
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final appState = await _loadedState();
    addTearDown(appState.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LogDiaperSheet(appState: appState)),
    ));
    await tester.pumpAndSettle();

    // No error before the user does anything (default type is Pee).
    expect(find.text('Pick a colour'), findsNothing);

    // Saving without choosing a colour must not silently no-op — it surfaces the
    // inline error on the colour card.
    await tester.tap(find.text('Save diaper log'));
    await tester.pump();
    expect(find.text('Pick a colour'), findsOneWidget);
    // Nothing was saved.
    expect(appState.diapers, isEmpty);

    // Choosing a colour clears the error.
    await tester.tap(find.text('Yellow'));
    await tester.pump();
    expect(find.text('Pick a colour'), findsNothing);
  });
}
