package com.allanweber.nestling

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.gdelataillade.alarm.models.AlarmSettings
import com.gdelataillade.alarm.services.AlarmScheduler
import com.gdelataillade.alarm.services.AlarmStorage

/**
 * Re-applies [RingPolicy] to a pending alarm moments before it rings.
 *
 * The `alarm` package bakes an alarm's settings into the PendingIntent at
 * schedule time, and a reminder is typically armed hours ahead — so deciding
 * "is the phone muted?" when the feed is logged answers the wrong question. The
 * guard is a second, tiny alarm of our own that fires [LEAD_MILLIS] before the
 * real one, reads the phone's state *then*, and rewrites the pending alarm if
 * the answer changed.
 *
 * It is deliberately additive: if the guard never runs (killed, denied, lost to
 * a reboot before [RingPolicyBootReceiver] catches up) the reminder still rings
 * exactly as it would have without it — with whatever policy applied at
 * schedule time. Failure is a stale decision, never a missed feed.
 */
object RingPolicyGuard {
    private const val TAG = "RingPolicyGuard"

    /**
     * How far ahead of the alarm the guard runs. Long enough that the rewrite
     * and the re-arm settle before AlarmManager delivers the real alarm, short
     * enough that the phone's state is still the state it will ring in.
     */
    private const val LEAD_MILLIS = 15_000L

    /** Below this the guard is pointless: schedule-time evaluation is current. */
    private const val MIN_LEAD_MILLIS = 2_000L

    const val ACTION_GUARD = "com.allanweber.nestling.action.RING_POLICY_GUARD"
    const val EXTRA_ID = "id"

    private const val PREFS = "nestling_ring_policy"

    /**
     * Remembers what the alarm was *meant* to sound like, so a guard run can
     * restore a muted alarm to its real sound when the phone is unmuted again.
     * Reading the pending alarm alone would only ever see the last decision.
     */
    private data class Spec(val atMillis: Long, val assetAudioPath: String, val vibrate: Boolean)

    /**
     * Records the intended ring for alarm [id] and arms the guard for it.
     * Replaces any guard already armed for the same id.
     */
    fun arm(context: Context, id: Int, atMillis: Long, assetAudioPath: String, vibrate: Boolean) {
        writeSpec(context, id, Spec(atMillis, assetAudioPath, vibrate))
        armAt(context, id, atMillis)
    }

    /** Forgets alarm [id] and disarms its guard. Safe to call for unknown ids. */
    fun cancel(context: Context, id: Int) {
        clearSpec(context, id)
        alarmManager(context)?.cancel(guardIntent(context, id))
    }

    /**
     * Re-arms every guard whose alarm is still in the future. AlarmManager
     * forgets everything across a reboot, so this runs at boot alongside the
     * `alarm` package's own restore.
     */
    fun rearmAll(context: Context) {
        val now = System.currentTimeMillis()
        for ((id, spec) in readAllSpecs(context)) {
            if (spec.atMillis <= now) clearSpec(context, id) else armAt(context, id, spec.atMillis)
        }
    }

    /**
     * The guard itself: decide how the phone should sound right now and rewrite
     * the pending alarm if it disagrees.
     */
    fun apply(context: Context, id: Int) {
        val spec = readSpec(context, id) ?: return

        val stored = try {
            AlarmStorage(context).getSavedAlarms().firstOrNull { it.id == id }
        } catch (e: Exception) {
            Log.e(TAG, "Cannot read pending alarms; leaving alarm $id as scheduled.", e)
            return
        }
        if (stored == null) {
            // Already rung, stopped or cancelled — nothing to guard.
            clearSpec(context, id)
            return
        }

        val policy = RingPolicyEvaluator.evaluate(context)
        val asset =
            if (policy.audible) spec.assetAudioPath else RingPolicyEvaluator.SILENT_ASSET
        val vibrate = spec.vibrate && policy != RingPolicy.SILENT

        if (stored.assetAudioPath == asset && stored.vibrate == vibrate) return

        Log.d(TAG, "Alarm $id: applying $policy (sound=$asset, vibrate=$vibrate).")
        reschedule(context, stored.copy(assetAudioPath = asset, vibrate = vibrate))
    }

    /**
     * Rewrites the pending alarm in place. `AlarmScheduler` re-saves it and
     * replaces the same PendingIntent (request code = alarm id), so this
     * updates the alarm rather than adding a second one.
     */
    private fun reschedule(context: Context, alarm: AlarmSettings) {
        try {
            AlarmScheduler.schedule(context, alarm)
        } catch (e: Exception) {
            // The alarm as originally scheduled is still armed; it just rings
            // with the older decision.
            Log.e(TAG, "Failed to re-arm alarm ${alarm.id} with the current ring policy.", e)
        }
    }

    private fun armAt(context: Context, id: Int, atMillis: Long) {
        val triggerAt = atMillis - LEAD_MILLIS
        if (triggerAt - System.currentTimeMillis() < MIN_LEAD_MILLIS) return

        val manager = alarmManager(context) ?: return
        val pending = guardIntent(context, id)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            } else {
                manager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            }
        } catch (e: Exception) {
            // Exact alarms revoked, or the per-app alarm limit reached. The
            // reminder still rings; it just keeps its schedule-time policy.
            Log.w(TAG, "Could not arm the ring-policy guard for alarm $id.", e)
        }
    }

    private fun guardIntent(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, RingPolicyGuardReceiver::class.java).apply {
            action = ACTION_GUARD
            putExtra(EXTRA_ID, id)
        }
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun alarmManager(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager

    // --- Spec storage --------------------------------------------------------
    // Its own SharedPreferences file rather than the Flutter store: the guard
    // runs with no engine, and these entries are native bookkeeping the Dart
    // side never reads.

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun writeSpec(context: Context, id: Int, spec: Spec) {
        prefs(context).edit()
            .putLong("at_$id", spec.atMillis)
            .putString("asset_$id", spec.assetAudioPath)
            .putBoolean("vibrate_$id", spec.vibrate)
            .apply()
    }

    private fun readSpec(context: Context, id: Int): Spec? {
        val p = prefs(context)
        val asset = p.getString("asset_$id", null) ?: return null
        return Spec(p.getLong("at_$id", 0L), asset, p.getBoolean("vibrate_$id", true))
    }

    private fun clearSpec(context: Context, id: Int) {
        prefs(context).edit()
            .remove("at_$id")
            .remove("asset_$id")
            .remove("vibrate_$id")
            .apply()
    }

    private fun readAllSpecs(context: Context): Map<Int, Spec> {
        val p = prefs(context)
        return p.all.keys
            .mapNotNull { it.removePrefixOrNull("asset_")?.toIntOrNull() }
            .mapNotNull { id -> readSpec(context, id)?.let { id to it } }
            .toMap()
    }

    private fun String.removePrefixOrNull(prefix: String): String? =
        if (startsWith(prefix)) removePrefix(prefix) else null
}

/**
 * Runs the work off the main thread while holding the broadcast open, since
 * both receivers below read the alarm store from disk.
 */
private fun BroadcastReceiver.runOffMainThread(tag: String, block: () -> Unit) {
    val pending = goAsync()
    Thread {
        try {
            block()
        } catch (e: Throwable) {
            Log.e(tag, "Ring policy work failed; the alarm rings as scheduled.", e)
        } finally {
            pending.finish()
        }
    }.start()
}

/** Runs [RingPolicyGuard.apply] shortly before an alarm is due. */
class RingPolicyGuardReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(RingPolicyGuard.EXTRA_ID, 0)
        if (id == 0) return
        val app = context.applicationContext
        runOffMainThread("RingPolicyGuardReceiver") { RingPolicyGuard.apply(app, id) }
    }
}

/** Restores the guards AlarmManager dropped when the device restarted. */
class RingPolicyBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON" -> {
                val app = context.applicationContext
                runOffMainThread("RingPolicyBootReceiver") { RingPolicyGuard.rearmAll(app) }
            }
        }
    }
}
