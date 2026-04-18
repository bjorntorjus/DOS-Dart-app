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
  final Random _random = Random();

  Future<void> init() async {
    _enabled = await AppSettings.getVideoEventsEnabled();
  }

  void setEnabled(bool value) {
    _enabled = value;
  }

  /// Show a specific [name].mp4 from assets/videos/ as an overlay.
  /// Does nothing if disabled or the asset file doesn't exist.
  Future<void> showVideo(BuildContext context, String name) async {
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
  Future<void> showRandomFromFolder(BuildContext context, String folder, {int chance = 1}) async {
    if (!_enabled) return;
    if (chance > 1 && _random.nextInt(chance) != 0) return;

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

      final picked = files[_random.nextInt(files.length)];
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
