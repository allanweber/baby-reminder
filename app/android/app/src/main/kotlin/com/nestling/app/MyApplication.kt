package com.nestling.app

import android.app.Application
import android.content.Context
import java.io.PrintWriter
import java.io.StringWriter

/// Captures otherwise-invisible native (JVM) crashes to disk before the process
/// dies, so the app can show the real Android crash reason on the next launch —
/// the app "just closing" (e.g. a foreground-service or notification exception
/// thrown by a plugin) leaves no Dart error, but this handler catches it.
///
/// It writes into the same SharedPreferences store the Flutter side reads
/// (`FlutterSharedPreferences`, keys prefixed `flutter.`), then delegates to the
/// previous handler so Android still crashes normally.
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val sw = StringWriter()
                throwable.printStackTrace(PrintWriter(sw))
                val text = "thread=${thread.name}\n$sw"
                getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .edit()
                    .putString("flutter.nativeCrash", text)
                    .commit() // synchronous: the process is about to die
            } catch (_: Throwable) {
                // Never let crash-recording itself crash.
            }
            previous?.uncaughtException(thread, throwable)
        }
    }
}
