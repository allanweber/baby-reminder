import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'services/alarm_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.create();
  final notifications = NotificationService();
  // Set up channels and ask for notification / exact-alarm permissions up front
  // so the alarm can fire (and show on the lock screen) even when the app is
  // closed, without waiting for the first feed to be logged.
  await notifications.init();
  final alarm = AlarmService();
  final appState = AppState(storage, notifications, alarm);
  await appState.load();
  runApp(BabyFeedTrackerApp(appState: appState));
}

class BabyFeedTrackerApp extends StatelessWidget {
  final AppState appState;
  const BabyFeedTrackerApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final title = appState.babyName.isNotEmpty ? "${appState.babyName}'s Feeds" : 'Baby Feed Tracker';
        return MaterialApp(
          title: title,
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(AppColors.accentBlush),
          home: AppShell(appState: appState),
        );
      },
    );
  }
}
