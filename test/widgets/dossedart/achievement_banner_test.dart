import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/achievement_service.dart';
import 'package:dart_scoring/widgets/dossedart/achievement_banner.dart';
import 'package:dart_scoring/widgets/dossedart/achievement_medal.dart';

Achievement _ach() => const Achievement(
      id: 'x01_maximum',
      name: 'MAXIMUM',
      description: 'Score a 180',
      tier: AchievementTier.gold,
      category: AchievementCategory.scoring,
      glyph: AchievementGlyph.icon(Icons.whatshot),
    );

AchievementUnlock _unlock(String name) =>
    AchievementUnlock(SavedPlayer(id: '1', name: name, createdAt: DateTime(2020)), _ach());

void main() {
  testWidgets('medal renders its glyph icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AchievementMedal(achievement: _ach())),
    ));
    expect(find.byIcon(Icons.whatshot), findsOneWidget);
  });

  testWidgets('host shows banner, then auto-dismisses, and never blocks taps',
      (tester) async {
    final controller = StreamController<AchievementUnlock>.broadcast();
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: AchievementOverlayHost(
        stream: controller.stream,
        display: const Duration(seconds: 3),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ElevatedButton(
              onPressed: () => tapped = true,
              child: const Text('UNDER'),
            ),
          ),
        ),
      ),
    ));

    controller.add(_unlock('Ada'));
    await tester.pump(); // process stream event
    await tester.pump(); // build banner
    expect(find.text('MAXIMUM'), findsOneWidget);

    // Banner overlays the top but must not eat taps on the button beneath.
    await tester.tap(find.text('UNDER'));
    expect(tapped, isTrue);

    // Auto-dismiss after the display duration.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('MAXIMUM'), findsNothing);

    await controller.close();
  });

  testWidgets('host queues multiple unlocks and shows them sequentially',
      (tester) async {
    final controller = StreamController<AchievementUnlock>.broadcast();
    await tester.pumpWidget(MaterialApp(
      home: AchievementOverlayHost(
        stream: controller.stream,
        display: const Duration(seconds: 2),
        child: const SizedBox.expand(),
      ),
    ));
    controller.add(_unlock('Ada'));
    controller.add(_unlock('Bo'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Ada unlocked'), findsOneWidget);
    expect(find.text('Bo unlocked'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Bo unlocked'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Bo unlocked'), findsNothing);
    await controller.close();
  });
}
