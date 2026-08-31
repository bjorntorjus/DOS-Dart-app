import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/event.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_home_screen.dart';
import 'package:dart_scoring/screens/home_screen.dart';
import 'package:dart_scoring/services/event_service.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/widgets/dossedart/arcade_frame.dart';

void main() {
  setUpAll(() => ArcadeFrame.disableBeamForTest = true);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EventService.resetForTest();
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026), rating: 1250),
      SavedPlayer(id: 'b', name: 'Bo', createdAt: DateTime(2026), rating: 1150),
    ]);
  });
  tearDown(EventService.resetForTest);

  void open() => EventService.active = EventRecord(
      id: 'evt',
      name: 'Jobbfest 2026',
      start: DateTime(2026, 8, 25),
      savedRatings: const {});

  testWidgets('DOSSEDART home: HIGH SCORES becomes the event name',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DossedartHomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('★ HIGH SCORES ★'), findsOneWidget);

    open();
    await tester.pumpWidget(const MaterialApp(home: DossedartHomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('★ JOBBFEST 2026 ★'), findsOneWidget);
    expect(find.text('★ HIGH SCORES ★'), findsNothing);
  });

  testWidgets('classic home: Leaderboard becomes the event name',
      (tester) async {
    open();
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Jobbfest 2026'), findsOneWidget);
    expect(find.text('Leaderboard'), findsNothing);
  });
}
