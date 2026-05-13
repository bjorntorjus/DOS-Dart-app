import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/sound_service.dart';
import 'package:dart_scoring/services/video_service.dart';

/// Deterministic initial SharedPreferences for integration tests.
///
/// Keys mirror what `AppSettings` reads. Anything not listed here falls
/// back to the production default — usually `false`/`null` — which is
/// what we want for a clean-slate test.
const Map<String, Object> _defaultPrefs = {
  'tts_next_player': false,
  'tts_throw_result': false,
  'tts_score': false,
  'tts_winner': false,
  'tts_game_events': false,
  'video_events_enabled': false,
  'use_dossedart_design': false,
};

/// Initialises platform-channel mocks and SharedPreferences for a test.
///
/// Call once at the start of each test, before `pumpWidget`. Optional
/// [savedPlayers] list seeds `PlayerStorage` (key 'saved_players') so the
/// test can navigate setup → game without driving the "Add Player" dialog.
Future<void> setupTestEnvironment({
  List<String> savedPlayers = const [],
}) async {
  // Seed SharedPreferences with deterministic flags + optional players.
  final initial = Map<String, Object>.from(_defaultPrefs);
  if (savedPlayers.isNotEmpty) {
    final list = savedPlayers.asMap().entries.map((e) {
      final id = 'test-player-${e.key}';
      return {
        'id': id,
        'name': e.value,
        'createdAt': DateTime.now().toIso8601String(),
        'rating': 1200.0,
        'gamesPlayed': 0,
        'gamesWon': 0,
        'totalTurnScore': 0.0,
        'totalTurns': 0,
        'highestTurnScore': 0,
        'avatarPath': null,
        'gamesJoinedMidway': 0,
        'gamesLeftMidway': 0,
        'modeStats': <String, dynamic>{},
        'headToHead': <String, dynamic>{},
        'ratingHistory': <dynamic>[],
      };
    }).toList();
    initial['saved_players'] = jsonEncode(list);
  }
  SharedPreferences.setMockInitialValues(initial);

  // Disable all audio output up-front. SoundService.init reads the kill-switch
  // from settings (which we haven't added one for yet), so call setEnabled
  // explicitly. battery_plus + audioplayers platform channels are mocked below.
  SoundService.instance.setEnabled(false);

  // VideoService.init() reads the prefs flag, but it's only called from
  // main.dart. Integration tests pump a screen directly, so the singleton
  // keeps its default _enabled = true. Disable it explicitly here to avoid
  // showRandomFromFolder opening a modal VideoOverlay that hangs the test.
  VideoService.instance.setEnabled(false);

  // Mock battery_plus channel — return 100 % and 'discharging' state forever.
  // `battery_plus` uses MethodChannel('dev.fluttercommunity.plus/battery') and
  // EventChannel('dev.fluttercommunity.plus/charging') under the hood.
  const batteryChannel = MethodChannel('dev.fluttercommunity.plus/battery');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(batteryChannel, (call) async {
    if (call.method == 'getBatteryLevel') return 100;
    if (call.method == 'getBatteryState') return 'discharging';
    return null;
  });

  // image_picker is not exercised by the 3 scenarios, but mock it harmlessly
  // so any indirect call doesn't open a system dialog on the emulator.
  const imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(imagePickerChannel, (call) async => null);
}

/// Tears down platform-channel mocks. Run from `tearDown(...)` if any test
/// suite reuses widgets across tests. The default per-test isolation means
/// most callers don't need this.
void teardownTestEnvironment() {
  const batteryChannel = MethodChannel('dev.fluttercommunity.plus/battery');
  const imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(batteryChannel, null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(imagePickerChannel, null);
}
