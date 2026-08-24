import 'package:flutter/material.dart';
import '../../services/app_settings.dart';
import '../../services/meme_service.dart';
import '../../services/sound_service.dart';
import '../../services/tts_service.dart';
import '../../services/video_service.dart';
import '../../theme/dossedart_tokens.dart';
import 'x01/dossedart_menu_sheet.dart';

/// Shows the shared DOSSEDART in-game menu bottom sheet (design A, 2026-08-24:
/// players card on top, AUDIO & FX toggles with inline meme sub-settings,
/// shot-clock toggle, exit). Identical across every cockpit, so each mode
/// wires its own [onPlayerOverview]/[onExit] and passes its live [meme]
/// service; everything else maps 1:1 to the existing service singletons.
///
/// [activePlayerCount] is the mode's current non-removed player count, shown
/// as "N ACTIVE" on the players card (null hides the counter).
///
/// The shot-clock toggle only flips the persisted setting — ShotClock re-reads
/// it at every turn start, so a mid-game flip takes effect from the next turn.
Future<void> showDossedartCockpitMenu(
  BuildContext context, {
  required MemeService meme,
  required VoidCallback onPlayerOverview,
  required VoidCallback onExit,
  int? activePlayerCount,
  ValueChanged<bool>? onSoundChanged,
  ValueChanged<bool>? onTtsChanged,
}) async {
  final sound = await AppSettings.getSoundEffectsEnabled();
  final video = await AppSettings.getVideoEventsEnabled();
  final memes = await AppSettings.getMemeEnabled();
  final tts = await AppSettings.getTtsEnabled();
  final memeFrequency = await AppSettings.getMemeFrequency();
  final offensive = await AppSettings.getMemeOffensive();
  final shotClock = await AppSettings.getShotClockEnabled();
  final shotClockSeconds = await AppSettings.getShotClockSeconds();
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
          initialMemeFrequency: memeFrequency,
          initialOffensive: offensive,
          initialShotClock: shotClock,
          shotClockSeconds: shotClockSeconds,
          activePlayerCount: activePlayerCount,
          onSoundChanged: (v) {
            SoundService.instance.setEnabled(v);
            AppSettings.setSoundEffectsEnabled(v);
            onSoundChanged?.call(v);
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
          onMemeFrequencyChanged: (v) {
            meme.setFrequency(v);
            AppSettings.setMemeFrequency(v);
          },
          onOffensiveChanged: (v) {
            meme.setOffensive(v);
            AppSettings.setMemeOffensive(v);
          },
          onShotClockChanged: (v) {
            AppSettings.setShotClockEnabled(v);
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
