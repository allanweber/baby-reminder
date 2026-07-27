# Nestling

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
flutter build appbundle --release  # Android App Bundle (.aab) for Google Play
flutter build apk --release        # APK for sideload testing
```

For a release-signed local build, create `android/key.properties` (git-ignored)
pointing at your keystore — see "Release signing" below. Without it, local
release builds fall back to debug signing.

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

`.github/workflows/android-build.yml` (repo root) builds and uploads a
release-signed App Bundle (`nestling-appbundle`, the `.aab` for Play) and an
APK (`nestling-apk`, for sideload testing) on every push/PR touching `app/`.
Signing uses the GitHub Actions secrets listed below; if they're absent (e.g.
a fork PR) the build falls back to debug signing so CI still passes. iOS
packaging isn't wired up yet — it needs Apple signing credentials, per the
handoff doc.

## Release signing

The upload keystore and its passwords are **not** committed. Release signing
resolves in this order (see `android/app/build.gradle`):

1. **Environment variables** — how CI signs:
   - `ANDROID_KEYSTORE_PATH` — path to the decoded keystore file
   - `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`
2. **`android/key.properties`** — a git-ignored file for local release builds:
   ```properties
   storeFile=/absolute/path/to/upload-keystore.jks
   storePassword=…
   keyAlias=upload
   keyPassword=…
   ```
3. Otherwise, **debug signing** (build still succeeds; not uploadable to Play).

### CI secrets to configure

In the repo's **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | base64 of `upload-keystore.jks` (`base64 -w0 upload-keystore.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore (store) password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password |

Keep an offline backup of the keystore + passwords. If you enroll in **Play App
Signing** (recommended), Google holds the app-signing key and this keystore is
only the *upload* key, which Google can reset if it's ever lost or leaked.
