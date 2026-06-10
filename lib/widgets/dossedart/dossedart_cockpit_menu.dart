import 'package:flutter/material.dart';
import '../../services/app_settings.dart';
import '../../services/meme_service.dart';
import '../../services/sound_service.dart';
import '../../services/tts_service.dart';
import '../../services/video_service.dart';
import '../../theme/dossedart_tokens.dart';
import 'x01/dossedart_menu_sheet.dart';

/// Shows the shared DOSSEDART in-game menu bottom sheet (sound / video / memes /
/// voice toggles + player overview + exit). Identical across every cockpit, so
/// each mode wires its own [onPlayerOverview]/[onExit] and passes its live
/// [meme] service; everything else maps 1:1 to the existing service singletons.
Future<void> showDossedartCockpitMenu(
  BuildContext context, {
  required MemeService meme,
  required VoidCallback onPlayerOverview,
  required VoidCallback onExit,
  ValueChanged<bool>? onTtsChanged,
}) async {
  final sound = await AppSettings.getSoundEffectsEnabled();
  final video = await AppSettings.getVideoEventsEnabled();
  final memes = await AppSettings.getMemeEnabled();
  final tts = await AppSettings.getTtsEnabled();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    backgroundColor: DossedartTokens.surface,
    builder: (sheetCtx) {
      return SafeArea(
        child: DossedartMenuSheet(
          initialSound: sound,
          initialVideo: video,
          initialMemes: memes,
          initialTts: tts,
          onSoundChanged: (v) {
            SoundService.instance.setEnabled(v);
            AppSettings.setSoundEffectsEnabled(v);
          },
          onVideoChanged: (v) {
            VideoService.instance.setEnabled(v);
            AppSettings.setVideoEventsEnabled(v);
          },
          onMemesChanged: (v) {
            meme.setEnabled(v);
            AppSettings.setMemeEnabled(v);
          },
          onTtsChanged: (v) {
            TtsService.instance.setEnabled(v);
            AppSettings.setTtsEnabled(v);
            onTtsChanged?.call(v);
          },
          onPlayerOverview: () {
            Navigator.pop(sheetCtx);
            onPlayerOverview();
          },
          onExit: () {
            Navigator.pop(sheetCtx);
            onExit();
          },
        ),
      );
    },
  );
}
