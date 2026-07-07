import 'dart:async';

import 'package:dart_scoring/services/battery_sampler.dart';
import 'package:dart_scoring/services/video_service.dart';
import 'package:dart_scoring/widgets/dossedart/arcade_frame.dart';

/// Applied automatically by flutter_test to EVERY test under test/.
/// Neutralizes the three unbounded-timer sources that made pumpAndSettle
/// hang for up to 10 minutes (audit F18): the VideoOverlay spinner, the
/// 35s ArcadeFrame beam and the 30s BatterySampler tick.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  VideoService.disableForTest = true;
  ArcadeFrame.disableBeamForTest = true;
  BatterySampler.disableForTest = true;
  await testMain();
}
