import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/dossedart/achievements_gallery_screen.dart';
import 'package:dart_scoring/screens/dossedart/dossedart_stats_screen.dart';
import 'package:dart_scoring/screens/dossedart/game_detail_screen.dart';
import 'package:dart_scoring/widgets/dossedart/arcade_frame.dart';

SavedPlayer _player(String id, String name, double rating,
    {Set<String> unlocked = const {}, List<RatingSnapshot>? history}) {
  return SavedPlayer(
    id: id,
    name: name,
    createdAt: DateTime(2020),
    rating: rating,
    gamesPlayed: 4,
    gamesWon: 2,
    unlockedAchievementIds: {...unlocked},
    ratingHistory: history,
  );
}

Future<void> _seed(List<SavedPlayer> players) async {
  SharedPreferences.setMockInitialValues({
    'saved_players': jsonEncode(players.map((p) => p.toJson()).toList()),
  });
}

void main() {
  setUpAll(() => ArcadeFrame.disableBeamForTest = true);

  testWidgets('renders the 4 arcade tabs', (tester) async {
    await _seed([_player('1', 'Ada', 1300)]);
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('PROFIL'), findsOneWidget);
    expect(find.text('MODUS'), findsOneWidget);
    expect(find.text('HEATMAP'), findsOneWidget);
    expect(find.text('HISTORIKK'), findsOneWidget);
  });

  testWidgets('PROFIL defaults to highest-rated and selector switches player',
      (tester) async {
    await _seed([_player('1', 'Ada', 1300), _player('2', 'Bo', 1200)]);
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();

    // Default = highest rated (Ada, 1300).
    expect(find.text('ELO 1300'), findsOneWidget);

    // Tap Bo in the selector → profile switches.
    await tester.tap(find.text('Bo'));
    await tester.pumpAndSettle();
    expect(find.text('ELO 1200'), findsOneWidget);
  });

  testWidgets('PRESTASJONER shows count and opens the gallery', (tester) async {
    await _seed([_player('1', 'Ada', 1300, unlocked: {'x_rookie'})]);
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('PRESTASJONER'), findsOneWidget);
    await tester.ensureVisible(find.text('VIEW ALL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIEW ALL'));
    await tester.pumpAndSettle();
    expect(find.byType(AchievementsGalleryScreen), findsOneWidget);
  });

  testWidgets('PROFIL sparkline paints rank-change markers without errors',
      (tester) async {
    // Ada overtakes Bo at the 2nd snapshot → rank 2 → 1 marker is drawn.
    await _seed([
      _player('1', 'Ada', 1300, history: [
        RatingSnapshot(date: DateTime(2026, 1, 1), rating: 1200),
        RatingSnapshot(date: DateTime(2026, 1, 2), rating: 1250),
        RatingSnapshot(date: DateTime(2026, 1, 3), rating: 1300),
      ]),
      _player('2', 'Bo', 1250, history: [
        RatingSnapshot(date: DateTime(2026, 1, 1), rating: 1230),
        RatingSnapshot(date: DateTime(2026, 1, 2), rating: 1240),
        RatingSnapshot(date: DateTime(2026, 1, 3), rating: 1250),
      ]),
    ]);
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('RATING HISTORY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a HISTORIKK row opens KAMPDETALJER', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final entry = GameHistoryEntry(
      id: '1', gameMode: 'x01', date: DateTime(2026, 6, 16),
      gameConfig: '501 · Double-Out',
      players: [
        GameHistoryPlayer(name: 'Ada', placement: 1, stats: const {}),
        GameHistoryPlayer(name: 'Bo', placement: 2, stats: const {}),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'saved_players': jsonEncode([_player('1', 'Ada', 1300).toJson()]),
      'game_history_v1': GameHistoryEntry.encodeList([entry]),
    });
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('HISTORIKK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DETALJER ›'));
    await tester.pumpAndSettle();

    expect(find.byType(GameDetailScreen), findsOneWidget);
    expect(find.text('KAMPDETALJER'), findsOneWidget);
  });

  testWidgets('empty state when no saved players', (tester) async {
    await _seed([]);
    await tester.pumpWidget(const MaterialApp(home: DossedartStatsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('NO SAVED PLAYERS YET'), findsOneWidget);
  });
}
