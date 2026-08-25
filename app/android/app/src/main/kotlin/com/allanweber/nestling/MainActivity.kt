package com.allanweber.nestling

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// The full-screen feed/reminder alarm is shown over the lock screen and wakes
// the display by the `alarm` package itself: its AlarmPlugin observes the
// ringing state and toggles setShowWhenLocked / setTurnScreenOn (and dismisses
// the keyguard) only while an alarm is sounding, reverting them when it stops.
// So this activity must NOT set those flags itself — doing so unconditionally
// left the whole app visible over the lock screen for its entire lifetime.
class MainActivity : FlutterActivity() {
    companion object {
        private const val RING_POLICY_CHANNEL = "com.allanweber.nestling/ring_policy"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Lets Dart apply the current mute/DND state when it arms an alarm, and
        // register the guard that re-checks it just before the alarm rings.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RING_POLICY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "evaluate" ->
                        result.success(RingPolicyEvaluator.evaluate(applicationContext).name)

                    "arm" -> {
                        RingPolicyGuard.arm(
                            applicationContext,
                            id = call.argument<Int>("id")!!,
                            atMillis = call.argument<Number>("atMillis")!!.toLong(),
                            assetAudioPath = call.argument<String>("assetAudioPath")!!,
                            vibrate = call.argument<Boolean>("vibrate") ?: true,
                        )
                        result.success(null)
                    }

                    "cancel" -> {
                        RingPolicyGuard.cancel(applicationContext, call.argument<Int>("id")!!)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
