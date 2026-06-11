import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/screens/dossedart/achievements_gallery_screen.dart';
import 'package:dart_scoring/widgets/dossedart/achievement_medal.dart';
import 'package:dart_scoring/widgets/dossedart/stats/prestasjoner_section.dart';

void main() {
  testWidgets('gallery shows description text without interaction',
      (tester) async {
    final player = SavedPlayer(id: '1', name: 'Ada', createdAt: DateTime(2020))
      ..unlockedAchievementIds.add('x_rookie');
    await tester.pumpWidget(MaterialApp(
      home: AchievementsGalleryScreen(player: player),
    ));
    await tester.pumpAndSettle();

    // ROOKIE is the first badge in the catalog → visible at the top of the
    // grid; its description must be rendered without any long-press.
    expect(find.text('Finish your first game'), findsOneWidget);
  });

  testWidgets('tapping a medal in PRESTASJONER opens an info dialog',
      (tester) async {
    final player = SavedPlayer(id: '1', name: 'Ada', createdAt: DateTime(2020))
      ..unlockedAchievementIds.add('x_rookie');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: PrestasjonerSection(player: player)),
      ),
    ));
    await tester.pumpAndSettle();

    // No description anywhere before tapping.
    expect(find.text('Finish your first game'), findsNothing);

    // The first medal in the RECENT row is the unlocked ROOKIE badge.
    await tester.tap(find.byType(AchievementMedal).first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('ROOKIE'), findsOneWidget);
    expect(find.text('Finish your first game'), findsOneWidget);
  });
}
