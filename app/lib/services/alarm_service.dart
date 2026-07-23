import 'package:audioplayers/audioplayers.dart';

/// A selectable alarm sound. [id] is the shared, resource-safe base name used
/// both for the bundled Flutter asset (`assets/sounds/<id>.wav`) and the
/// Android notification raw resource (`res/raw/<id>`).
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
const kDefaultAlarmVolume = 0.8;

String resolveAlarmSoundId(String? id) =>
    kAlarmSounds.any((s) => s.id == id) ? id! : kDefaultAlarmSound;

/// Plays the reminder alarm in-app while the app is open: a looping sound at a
/// user-set volume that keeps going until it is explicitly stopped (dismiss /
/// snooze / log). The scheduled OS notification is the fallback for when the
/// app isn't open — see [NotificationService].
class AlarmService {
  // Created lazily on first playback so simply constructing the service (e.g.
  // in a widget test with no audio plugin registered) makes no platform calls.
  AudioPlayer? _playerInstance;
  AudioPlayer? _previewInstance;
  bool _ringing = false;

  AudioPlayer get _player => _playerInstance ??= AudioPlayer(playerId: 'feed_alarm_loop');
  AudioPlayer get _preview => _previewInstance ??= AudioPlayer(playerId: 'feed_alarm_preview');

  bool get isRinging => _ringing;

  AudioContext get _alarmContext => AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gain,
        ),
      );

  /// Start (or restart) the looping alarm.
  Future<void> start({required String soundId, required double volume}) async {
    final id = resolveAlarmSoundId(soundId);
    final v = volume.clamp(0.0, 1.0);
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setAudioContext(_alarmContext);
      await _player.setVolume(v);
      await _player.play(AssetSource('sounds/$id.wav'), volume: v);
      _ringing = true;
    } catch (_) {
      _ringing = false;
    }
  }

  Future<void> setVolume(double volume) async {
    if (!_ringing) return;
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> stop() async {
    _ringing = false;
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// One-shot, non-looping playback for the settings preview.
  Future<void> previewSound({required String soundId, required double volume}) async {
    final id = resolveAlarmSoundId(soundId);
    final v = volume.clamp(0.0, 1.0);
    try {
      await _preview.setReleaseMode(ReleaseMode.release);
      await _preview.setAudioContext(_alarmContext);
      await _preview.play(AssetSource('sounds/$id.wav'), volume: v);
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _playerInstance?.dispose();
    } catch (_) {}
    try {
      await _previewInstance?.dispose();
    } catch (_) {}
  }
}
