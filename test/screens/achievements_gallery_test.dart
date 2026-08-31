import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/dossedart/achievements_gallery_screen.dart';
import 'package:dart_scoring/widgets/dossedart/achievement_medal.dart';

void main() {
  testWidgets('gallery shows a medal per catalog entry and the progress count',
      (tester) async {
    final player = SavedPlayer(id: '1', name: 'Ada', createdAt: DateTime(2020))
      ..unlockedAchievementIds.add('x_rookie');
    await tester.pumpWidget(MaterialApp(
      home: AchievementsGalleryScreen(player: player),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AchievementMedal), findsWidgets);
    // Progress label reflects 1 unlocked out of the full catalog.
    expect(find.text('1 / ${achievementCatalog.length}'), findsOneWidget);
  });

  testWidgets('tier filter narrows the grid', (tester) async {
    final player = SavedPlayer(id: '1', name: 'Ada', createdAt: DateTime(2020));
    await tester.pumpWidget(MaterialApp(
      home: AchievementsGalleryScreen(player: player),
    ));
    await tester.pumpAndSettle();
    // ROOKIE is a bronze badge at the top of the grid → rendered under "ALL".
    expect(find.text('ROOKIE'), findsOneWidget);

    await tester.tap(find.text('GOLD'));
    await tester.pumpAndSettle();
    // Filtering to GOLD drops the bronze ROOKIE and still shows some medals.
    expect(find.text('ROOKIE'), findsNothing);
    expect(find.byType(AchievementMedal), findsWidgets);
  });

  testWidgets('unlocked achievements are listed before locked ones',
      (tester) async {
    // Pick a badge that is NOT first in the catalog so the sort is observable.
    final late = achievementCatalog.last;
    final player = SavedPlayer(id: '1', name: 'Ada', createdAt: DateTime(2020))
      ..unlockedAchievementIds.add(late.id);
    await tester.pumpWidget(MaterialApp(
      home: AchievementsGalleryScreen(player: player),
    ));
    await tester.pumpAndSettle();

    final medals = tester
        .widgetList<AchievementMedal>(find.byType(AchievementMedal))
        .toList();
    expect(medals.first.achievement.id, late.id);
    expect(medals.first.unlocked, isTrue);
    expect(medals.skip(1).every((m) => !m.unlocked), isTrue);
  });
}
