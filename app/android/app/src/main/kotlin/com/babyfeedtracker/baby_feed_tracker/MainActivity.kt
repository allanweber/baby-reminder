package com.babyfeedtracker.baby_feed_tracker

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Let the app (and so the full-screen feed alarm) appear over the lock
    // screen and wake the display, so the alarm can be seen and dismissed
    // without unlocking the phone first.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }
}
