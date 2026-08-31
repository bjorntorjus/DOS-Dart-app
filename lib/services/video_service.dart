import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/video_overlay.dart';
import 'app_settings.dart';

/// Shows event videos/GIFs from assets/videos/.
/// Supports folder-based random selection and frequency control.
/// Falls back silently if the file doesn't exist or video is disabled.
class VideoService {
  VideoService._();
  static final VideoService instance = VideoService._();

  bool _enabled = true;
  int _frequency = 5;

  /// Injectable for deterministic dice tests; production leaves the default.
  @visibleForTesting
  Random random = Random();

  /// F18: hard off-switch for tests. Checked at show-time so the async
  /// prefs re-read in init() cannot re-enable videos mid-test.
  @visibleForTesting
  static bool disableForTest = false;

  Future<void> init() async {
    _enabled = await AppSettings.getVideoEventsEnabled();
    _frequency = await AppSettings.getVideoFrequency();
  }

  void setEnabled(bool value) {
    _enabled = value;
  }

  void setFrequency(int value) {
    _frequency = value;
  }

  /// Frequency (1-10) → chance denominator, same scale as the meme dice:
  /// 1=1/8, 5=1/4 (default), 8=1/2, 10=always.
  static int frequencyToChance(int frequency) {
    if (frequency >= 10) return 1;
    if (frequency >= 8) return 2;
    if (frequency >= 6) return 3;
    if (frequency >= 4) return 4;
    if (frequency >= 2) return 6;
    return 8;
  }

  /// The decision seam for every video (video-damping 2026-07-22: all call
  /// sites showed their video 100% of the time — the winner video played
  /// after every single game). Rolls the GLOBAL frequency dice (bypassed at
  /// frequency 10 = "always"), then any explicit per-call [chance] on top.
  ///
  /// Public because the cockpits must know IN ADVANCE whether a video will
  /// play, so they can mute the meme sound that would otherwise talk over it.
  /// Those callers pass `alreadyDecided: true` to [showRandomFromFolder] so
  /// the dice are not rolled a second time (audit 2026-08-10, F2).
  bool shouldPlay({int chance = 1}) {
    if (!_enabled) return false;
    final globalChance = frequencyToChance(_frequency);
    if (globalChance > 1 && random.nextInt(globalChance) != 0) return false;
    if (chance > 1 && random.nextInt(chance) != 0) return false;
    return true;
  }

  /// Show a specific [name].mp4 from assets/videos/ as an overlay.
  /// Does nothing if disabled or the asset file doesn't exist.
  Future<void> showVideo(BuildContext context, String name) async {
    if (disableForTest) return;
    if (!_enabled) return;
    final path = 'assets/videos/$name.mp4';
    try {
      await rootBundle.load(path);
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => VideoOverlay(assetPath: path),
    );
  }

  /// Show a random video/GIF from [folder] inside assets/videos/.
  /// Only plays with a 1-in-[chance] probability (default: always).
  /// Supports .mp4 and .gif files.
  ///
  /// Pass [alreadyDecided] when the caller has already rolled [shouldPlay]
  /// itself — rolling again here would re-create the double gate the
  /// 2026-08-10 audit removed. [chance] is ignored when it is set.
  Future<void> showRandomFromFolder(BuildContext context, String folder,
      {int chance = 1, bool alreadyDecided = false}) async {
    if (disableForTest) return;
    if (!_enabled) return;
    if (!alreadyDecided && !shouldPlay(chance: chance)) return;

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final prefix = 'assets/videos/$folder/';
      final files = manifest
          .listAssets()
          .where((key) =>
              key.startsWith(prefix) &&
              (key.endsWith('.mp4') || key.endsWith('.gif')))
          .toList();

      if (files.isEmpty) return;

      final picked = files[random.nextInt(files.length)];
      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => VideoOverlay(assetPath: picked),
      );
    } catch (_) {
      // Silently ignore manifest or playback errors
    }
  }
}
