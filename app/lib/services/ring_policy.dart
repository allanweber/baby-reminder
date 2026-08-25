import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// How loudly an alarm may ring given the phone's current state.
enum RingPolicy {
  /// Ring normally, at the device's alarm volume.
  audible,

  /// No sound, but still vibrate and take over the screen.
  vibrateOnly,

  /// No sound and no vibration; the alarm is still shown.
  silent;

  bool get isAudible => this == RingPolicy.audible;
  bool get vibrates => this != RingPolicy.silent;
}

/// Bridge to the native ring policy (see `RingPolicy.kt` / `RingPolicyGuard.kt`).
///
/// The `alarm` package rings through a MediaPlayer on Android's alarm stream,
/// which the OS deliberately exempts from silent mode, vibrate mode and Do Not
/// Disturb. Honouring those is therefore this app's own decision, and it has to
/// be made twice: once here, when the alarm is armed, and again natively a few
/// seconds before it rings — a reminder set after a feed is usually hours old by
/// the time it goes off, and the phone may have been muted in between.
class RingPolicyBridge {
  static const _channel = MethodChannel('com.allanweber.nestling/ring_policy');

  /// A second of digital silence, played in place of the chosen sound when the
  /// phone is muted. Substituting the asset keeps the full-screen alarm, the
  /// notification and the vibration, and never touches the device's own alarm
  /// volume — so nothing here can leave the user's clock alarm muted.
  static const silentAsset = 'assets/sounds/silent.wav';

  /// Android-only. Everywhere else the platform already applies its own rules,
  /// so the policy is always [RingPolicy.audible].
  static bool get _supported => Platform.isAndroid;

  /// The policy that applies right now. Falls back to [RingPolicy.audible] if
  /// the platform can't answer: ringing too loudly is recoverable, a reminder
  /// that never makes a sound is not.
  static Future<RingPolicy> current() async {
    if (!_supported) return RingPolicy.audible;
    try {
      final name = await _channel.invokeMethod<String>('evaluate');
      switch (name) {
        case 'SILENT':
          return RingPolicy.silent;
        case 'VIBRATE_ONLY':
          return RingPolicy.vibrateOnly;
        default:
          return RingPolicy.audible;
      }
    } catch (_) {
      return RingPolicy.audible;
    }
  }

  /// Registers the alarm's intended sound so the native guard can re-decide,
  /// [atMillis], whether it should actually be heard — including restoring the
  /// real sound if the phone was unmuted since it was armed.
  static Future<void> arm({
    required int id,
    required DateTime at,
    required String assetAudioPath,
    required bool vibrate,
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('arm', {
        'id': id,
        'atMillis': at.millisecondsSinceEpoch,
        'assetAudioPath': assetAudioPath,
        'vibrate': vibrate,
      });
    } catch (_) {}
  }

  /// Drops the guard for a cancelled or stopped alarm.
  static Future<void> cancel(int id) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('cancel', {'id': id});
    } catch (_) {}
  }
}
