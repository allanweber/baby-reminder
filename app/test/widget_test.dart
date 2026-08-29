import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baby_feed_tracker/main.dart';
import 'package:baby_feed_tracker/services/alarm_service.dart';
import 'package:baby_feed_tracker/services/notification_service.dart';
import 'package:baby_feed_tracker/services/storage_service.dart';
import 'package:baby_feed_tracker/state/app_state.dart';

void main() {
  testWidgets('App lands on the Home (daily report) tab; Feed tab still renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    final appState = AppState(storage, NotificationService(), AlarmService());
    await appState.load();

    await tester.pumpWidget(BabyFeedTrackerApp(appState: appState));
    await tester.pump();

    // Cold start lands on the daily-report tab, and the bottom bar shows the
    // "Home" tab where "Report" used to be.
    expect(find.text('Daily report'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);

    // The Feed screen is still built in the IndexedStack (offstage until its tab
    // is selected) and renders its log button and today's feeds.
    expect(find.text('Log feed now', skipOffstage: false), findsOneWidget);
    expect(find.text("Today's feeds", skipOffstage: false), findsWidgets);

    appState.dispose();
  });
}
