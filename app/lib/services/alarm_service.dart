import 'package:audioplayers/audioplayers.dart';

/// A selectable alarm sound. [id] is the shared, resource-safe base name used
/// both for the bundled Flutter asset (`assets/sounds/<id>.wav`) and the
/// `alarm` package's alarm audio.
class AlarmSound {
  final String id;
  final String label;
  const AlarmSound(this.id, this.label);
}

const kAlarmSounds = <AlarmSound>[
  AlarmSound('alarm_chime', 'Chime'),
  AlarmSound('alarm_gentle', 'Gentle'),
  AlarmSound('alarm_classic', 'Classic'),
];

const kDefaultAlarmSound = 'alarm_chime';

String resolveAlarmSoundId(String? id) =>
    kAlarmSounds.any((s) => s.id == id) ? id! : kDefaultAlarmSound;

/// Plays a short preview of an alarm sound for the Settings screen.
///
/// The actual reminder now rings through the `alarm` package (see
/// [NotificationService]), which is the single alarm engine — it fires with
/// sound + vibration + a full-screen takeover whether the app is open, closed,
/// or the phone is locked. This service is used only to let the user hear a
/// sound while choosing it; it deliberately does no scheduling and never runs a
/// second, competing looped alarm.
class AlarmService {
  // Created lazily on first playback so simply constructing the service (e.g.
  // in a widget test with no audio plugin registered) makes no platform calls.
  AudioPlayer? _previewInstance;

  AudioPlayer get _preview => _previewInstance ??= AudioPlayer(playerId: 'feed_alarm_preview');

  AudioContext get _alarmContext => AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gain,
        ),
      );

  /// One-shot, non-looping playback for the settings preview.
  ///
  /// Plays on the alarm audio stream at full player volume, so the preview
  /// tracks the device's current alarm volume — the same loudness a real
  /// reminder rings at. It deliberately does not force a fixed level.
  Future<void> previewSound({required String soundId}) async {
    final id = resolveAlarmSoundId(soundId);
    try {
      await _preview.setReleaseMode(ReleaseMode.release);
      await _preview.setAudioContext(_alarmContext);
      await _preview.play(AssetSource('sounds/$id.wav'), volume: 1.0);
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _previewInstance?.dispose();
    } catch (_) {}
  }
}
