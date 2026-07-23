import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baby_feed_tracker/main.dart';
import 'package:baby_feed_tracker/services/notification_service.dart';
import 'package:baby_feed_tracker/services/storage_service.dart';
import 'package:baby_feed_tracker/state/app_state.dart';

void main() {
  testWidgets('Home screen shows the log button and today\'s feeds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    final appState = AppState(storage, NotificationService());
    await appState.load();

    await tester.pumpWidget(BabyFeedTrackerApp(appState: appState));
    await tester.pump();

    expect(find.text('Log feed now'), findsOneWidget);
    expect(find.text("Today's feeds"), findsWidgets);

    appState.dispose();
  });
}
