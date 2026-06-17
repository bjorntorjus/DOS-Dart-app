import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/dart_throw.dart';
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
}
