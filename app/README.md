# Baby Feed Tracker

A one-handed, calming Flutter app for logging baby formula/bottle/breastfeeding
feeds, with an in-app + local-notification reminder for the next feed and a
per-day report. Single baby, single user, fully offline (all data lives on
device via `shared_preferences`).

Implements the design in `../Baby Feed Tracker.dc.html` and
`../design_handoff_baby_feed_tracker/README.md` — see those for the full
visual/behavior spec this was built from.

## Getting started

```bash
flutter pub get
flutter run            # run on a connected device/emulator
flutter analyze         # static analysis
flutter test             # widget tests
flutter build apk --release   # Android APK (signed with the debug keystore for now)
```

## Structure

- `lib/models/feed.dart` — the `Feed` data model.
- `lib/state/app_state.dart` — all domain logic: feeds, reminder scheduling,
  stats, persistence (ported from the prototype's `Component` class).
- `lib/services/storage_service.dart` — `SharedPreferences`-backed persistence.
- `lib/services/notification_service.dart` — schedules the next-feed reminder
  as a real local notification (`flutter_local_notifications`), so it fires
  even when the app is backgrounded.
- `lib/theme/` — design tokens (colors, radii, shadows) lifted from the
  handoff.
- `lib/widgets/` — reusable pieces: feed list row, reminder banner, log-feed
  sheet, settings sheet, delete confirmation, FAB, icons.
- `lib/screens/` — `HomeScreen`, `ReportScreen`, and the `AppShell` that hosts
  the persistent bottom tab bar + FAB around both.

## CI

`.github/workflows/android-build.yml` (repo root) builds and uploads a release
APK on every push/PR touching `app/`. iOS packaging isn't wired up yet — it
needs Apple signing credentials, per the handoff doc.

## Notes / follow-ups

- The release APK is currently signed with the Flutter debug keystore
  (see `android/app/build.gradle`) so CI needs no secrets. Add a real
  signing config + `secrets.*` before shipping to the Play Store.
- No custom launcher icon was specified in the design (it only defines
  in-app iconography); the default Flutter launcher icon is currently in use.
