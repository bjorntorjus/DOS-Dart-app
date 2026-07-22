import 'dart:async';

import 'package:dart_scoring/services/battery_sampler.dart';
import 'package:dart_scoring/services/sound_service.dart';
import 'package:dart_scoring/services/video_service.dart';
import 'package:dart_scoring/widgets/dossedart/arcade_frame.dart';

/// Applied automatically by flutter_test to EVERY test under test/.
/// Neutralizes the four unbounded-timer sources that made pumpAndSettle
/// hang for up to 10 minutes (audit F18): the VideoOverlay spinner, the
/// 35s ArcadeFrame beam, the 30s BatterySampler tick, and (2026-07-15)
/// SoundService's stall watchdog — a real/FakeAsync Timer that most
/// widget tests never elapse or cancel, which would otherwise trip
/// flutter_test's "no pending timers" invariant in any test exercising
/// game-event sound effects.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  VideoService.disableForTest = true;
  ArcadeFrame.disableBeamForTest = true;
  BatterySampler.disableForTest = true;
  SoundService.disableForTest = true;
  await testMain();
}
