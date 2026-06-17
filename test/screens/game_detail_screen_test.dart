import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/dart_throw.dart';
import 'package:dart_scoring/models/earned_feat.dart';
import 'package:dart_scoring/models/game_history.dart';
import 'package:dart_scoring/screens/dossedart/game_detail_screen.dart';
import 'package:dart_scoring/widgets/dossedart/arcade_frame.dart';

GameHistoryEntry _x01Entry({List<DartThrow>? throws}) => GameHistoryEntry(
      id: '1',
      gameMode: 'x01',
      date: DateTime(2026, 6, 16),
      gameConfig: '501 · Double-Out',
      durationSeconds: 600,
      throwHistory: throws,
      players: [
        GameHistoryPlayer(
          name: 'Jonas', placement: 1, stats: const {'darts': 15},
          ratingBefore: 1000, ratingAfter: 1012,
        ),
        GameHistoryPlayer(
          name: 'Mia', placement: 2, stats: const {'darts': 18},
          ratingBefore: 1000, ratingAfter: 988,
        ),
      ],
    );

void main() {
  setUpAll(() => ArcadeFrame.disableBeamForTest = true);

  testWidgets('renders standings + banner', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester
        .pumpWidget(MaterialApp(home: GameDetailScreen(entry: _x01Entry())));
    await tester.pumpAndSettle();

    expect(find.text('KAMPDETALJER'), findsOneWidget);
    expect(find.text('Jonas'), findsWidgets);
    expect(find.text('Mia'), findsWidgets);
    expect(find.textContaining('501'), findsWidgets); // banner config
    expect(find.textContaining('+12'), findsWidgets); // winner ΔELO
  });

  testWidgets('renders earned-feat chips', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final entry = GameHistoryEntry(
      id: '2', gameMode: 'x01', date: DateTime(2026, 6, 16),
      gameConfig: '501 · Double-Out',
      players: [
        GameHistoryPlayer(
          name: 'Jonas', placement: 1, stats: const {},
          earnedFeats: const [EarnedFeat(
              label: '180!', tier: AchievementTier.gold, kind: FeatKind.feat)],
        ),
        GameHistoryPlayer(name: 'Mia', placement: 2, stats: const {}),
      ],
    );

    await tester
        .pumpWidget(MaterialApp(home: GameDetailScreen(entry: entry)));
    await tester.pumpAndSettle();

    expect(find.text('PRESTASJONER DENNE KAMPEN'), findsOneWidget);
    expect(find.text('180!'), findsOneWidget);
  });

  testWidgets('renders progression chart when throwHistory present',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final throws = [
      for (var p = 0; p < 2; p++)
        for (var r = 1; r <= 2; r++)
          DartThrow(playerIndex: p, segment: 20, multiplier: 3, points: 60,
              scoreBefore: 501, turnNumber: 0, scoreAtStartOfTurn: 501 - (r - 1) * 60,
              turnId: r, roundNumber: r),
    ];
    await tester.pumpWidget(
        MaterialApp(home: GameDetailScreen(entry: _x01Entry(throws: throws))));
    await tester.pumpAndSettle();

    expect(find.text('SPILLFORLØP'), findsOneWidget);
  });
}
