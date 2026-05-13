import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/widgets/dossedart/setup/dossedart_setup_scaffold.dart';

Future<void> _seedPlayers(List<String> names) async {
  SharedPreferences.setMockInitialValues({});
  final saved = <SavedPlayer>[];
  for (final n in names) {
    saved.add(await PlayerStorage.addPlayer(n));
  }
  await PlayerStorage.savePlayers(saved);
}

Widget _harness({
  required int minPlayers,
  required String Function(int) summaryBuilder,
  required void Function(List<Player>, bool) onStart,
}) {
  return MaterialApp(
    home: DossedartSetupScaffold(
      title: 'TEST',
      rulesSection: (_, __) => const SizedBox.shrink(),
      minPlayers: minPlayers,
      summaryBuilder: summaryBuilder,
      onStart: onStart,
    ),
  );
}

void main() {
  // NOTE: ArcadeFrame runs a continuous AnimationController, so we never use
  // pumpAndSettle (it would hang). Instead, pump twice — once to render the
  // loading state, once after a small duration to let _load()'s async future
  // resolve.
  Future<void> _settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('start button disabled when zero players selected', (tester) async {
    await _seedPlayers(['Alice', 'Bob']);
    bool called = false;
    await tester.pumpWidget(_harness(
      minPlayers: 2,
      summaryBuilder: (_) => '',
      onStart: (_, __) => called = true,
    ));
    await _settle(tester);
    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pump();
    expect(called, isFalse);
  });

  testWidgets('summary shows MIN N when under threshold', (tester) async {
    await _seedPlayers(['Alice', 'Bob']);
    await tester.pumpWidget(_harness(
      minPlayers: 2,
      summaryBuilder: (n) => '$n PLAYERS',
      onStart: (_, __) {},
    ));
    await _settle(tester);
    // CAST header shows MIN; we verify the cast header label.
    expect(find.text('0 READY · MIN 2'), findsOneWidget);
  });

  testWidgets('start triggers onStart with selected players', (tester) async {
    await _seedPlayers(['Alice', 'Bob', 'Carol']);
    List<Player>? captured;
    bool? randomized;
    await tester.pumpWidget(_harness(
      minPlayers: 2,
      summaryBuilder: (_) => '',
      onStart: (p, r) {
        captured = p;
        randomized = r;
      },
    ));
    await _settle(tester);
    // Tap Alice and Carol. Names render uppercased in tiles.
    await tester.tap(find.text('ALICE'));
    await tester.pump();
    await tester.tap(find.text('CAROL'));
    await tester.pump();
    // Scroll the START button into view if needed.
    await tester.ensureVisible(find.text('▶ START MATCH ◀'));
    await tester.pump();
    await tester.tap(find.text('▶ START MATCH ◀'));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.length, 2);
    expect(randomized, isTrue); // default RANDOM ORDER on
  });
}
