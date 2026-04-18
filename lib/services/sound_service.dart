import 'dart:collection';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'app_settings.dart';
import 'game_logger.dart';

/// Plays short sound effect files from assets/sounds/.
/// Sounds are queued so they never overlap each other.
/// Falls back silently if a file doesn't exist or playback fails.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer();
  final Queue<String> _queue = Queue<String>();
  final Random _random = Random();
  bool _enabled = true;
  bool _isPlaying = false;

  Future<void> init() async {
    _enabled = await AppSettings.getSoundEffectsEnabled();
    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _playNextQueued();
    });
  }

  void setEnabled(bool value) {
    _enabled = value;
  }

  /// Play [name].mp3 from assets/sounds/. Queued — will not overlap other sounds.
  Future<void> play(String name) async {
    if (!_enabled) return;
    GameLogger.instance.logSound(source: 'SoundService', event: 'play($name)', outcome: 'queued (queueLen=${_queue.length}, playing=$_isPlaying)');
    _queue.add(name);
    if (!_isPlaying) _playNextQueued();
  }

  void _playNextQueued() {
    if (_queue.isEmpty) {
      _isPlaying = false;
      return;
    }
    final name = _queue.removeFirst();
    _isPlaying = true;
    _player.play(AssetSource('sounds/$name.mp3')).catchError((_) {
      _isPlaying = false;
      _playNextQueued();
    });
  }

  /// Like [playRandom], but only plays with a 1-in-[chance] probability.
  /// Default chance is 3 (≈33%). Useful for avoiding sound fatigue on frequent events.
  /// Returns true if the sound was selected to play, false if skipped by chance.
  bool playRandomMaybe(List<String> folders, {int chance = 3}) {
    if (_random.nextInt(chance) != 0) {
      GameLogger.instance.logSound(source: 'SoundService', event: 'playRandomMaybe($folders)', outcome: 'skipped by chance (1/$chance)');
      return false;
    }
    GameLogger.instance.logSound(source: 'SoundService', event: 'playRandomMaybe($folders)', outcome: 'playing (1/$chance hit)');
    playRandom(folders);
    return true;
  }

  /// Play a random .mp3 from one or more asset folders (paths relative to assets/sounds/).
  /// Files from all listed folders are merged into one pool before picking.
  Future<void> playRandom(List<String> folders, {String? fallback}) async {
    if (!_enabled) return;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final files = <String>[];
      for (final folder in folders) {
        final prefix = 'assets/sounds/$folder/';
        files.addAll(manifest
            .listAssets()
            .where((key) => key.startsWith(prefix) && key.endsWith('.mp3')));
      }
      if (files.isEmpty) {
        if (fallback != null) play(fallback);
        return;
      }
      final picked = files[_random.nextInt(files.length)];
      final name = picked
          .replaceFirst('assets/sounds/', '')
          .replaceAll(RegExp(r'\.mp3$'), '');
      play(name);
    } catch (_) {
      // Silently ignore manifest or playback errors
    }
  }
}
