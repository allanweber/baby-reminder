package com.allanweber.nestling

import io.flutter.embedding.android.FlutterActivity

// The full-screen feed/reminder alarm is shown over the lock screen and wakes
// the display by the `alarm` package itself: its AlarmPlugin observes the
// ringing state and toggles setShowWhenLocked / setTurnScreenOn (and dismisses
// the keyguard) only while an alarm is sounding, reverting them when it stops.
// So this activity must NOT set those flags itself — doing so unconditionally
// left the whole app visible over the lock screen for its entire lifetime.
class MainActivity : FlutterActivity()
