package com.allanweber.nestling

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import android.os.Build

/**
 * How loudly a reminder is allowed to ring, given the phone's state right now.
 *
 * The `alarm` package plays through a MediaPlayer with USAGE_ALARM on
 * STREAM_ALARM. Android deliberately exempts that stream from silent mode,
 * vibrate mode and Do Not Disturb — that is what makes a clock alarm still wake
 * you — so honouring those settings is a decision this app has to make itself.
 */
enum class RingPolicy {
    /** Ring normally, at the device's alarm volume. */
    AUDIBLE,

    /** No sound, but still vibrate and take over the screen. */
    VIBRATE_ONLY,

    /** No sound and no vibration; the alarm is still shown. */
    SILENT;

    val audible: Boolean get() = this == AUDIBLE
}

object RingPolicyEvaluator {
    /**
     * A second of digital silence, looped in place of the chosen alarm sound
     * when the phone is muted. Substituting the asset — rather than turning the
     * volume down — keeps the full-screen alarm, the notification and the
     * vibration intact, and never touches the device's own alarm volume, so a
     * failure here can't leave the user's clock alarm muted.
     */
    const val SILENT_ASSET = "assets/sounds/silent.wav"

    fun evaluate(context: Context): RingPolicy {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager

        when (audio?.ringerMode) {
            // Silent means silent: Android does not vibrate in this mode either.
            AudioManager.RINGER_MODE_SILENT -> return RingPolicy.SILENT
            AudioManager.RINGER_MODE_VIBRATE -> return RingPolicy.VIBRATE_ONLY
        }

        // Every Do Not Disturb mode counts, including "Alarms only". Android
        // lets alarms through DND by default; the user asked for reminders to
        // stay quiet instead, so this app opts out of that exemption.
        if (dndActive(context)) return RingPolicy.VIBRATE_ONLY

        // The alarm stream itself turned all the way down is an explicit "no
        // sound" too, and MediaPlayer would otherwise still be started.
        if (audio != null && audio.getStreamVolume(AudioManager.STREAM_ALARM) == 0) {
            return RingPolicy.VIBRATE_ONLY
        }

        return RingPolicy.AUDIBLE
    }

    /**
     * Reading the current zen mode needs no permission (unlike *setting* it,
     * which is what ACCESS_NOTIFICATION_POLICY gates), so this works from a
     * background receiver with no UI and no engine.
     */
    private fun dndActive(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return false
        return when (manager.currentInterruptionFilter) {
            NotificationManager.INTERRUPTION_FILTER_PRIORITY,
            NotificationManager.INTERRUPTION_FILTER_ALARMS,
            NotificationManager.INTERRUPTION_FILTER_NONE -> true
            // INTERRUPTION_FILTER_ALL, or UNKNOWN on a device that won't say.
            else -> false
        }
    }
}
