import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/game_config.dart';
import 'package:dart_scoring/models/player.dart';
import 'package:dart_scoring/models/wildcard_events.dart';
import 'package:dart_scoring/screens/wildcard_game_screen.dart';
import 'package:dart_scoring/services/tts_service.dart';
import 'package:dart_scoring/theme/dossedart_tokens.dart';
import 'package:dart_scoring/widgets/dossedart/wildcard/dossedart_wildcard_dialogs.dart';
import 'package:dart_scoring/widgets/dossedart/wildcard/dossedart_wildcard_scorecard.dart';
import 'package:dart_scoring/widgets/dossedart/x01/dossedart_x01_dartboard.dart';

/// Widget tests for the WILDCARD cockpit: renders, registers darts via the
/// @visibleForTesting hooks, and drives the overlay state machine (bull
/// choice, forced-modifier announcement + dimming, input guard while an
/// overlay is up).
///
/// Most scenarios pin `startingChaos: 0` so the RNG-driven turn-modifier
/// roll (`wcModifierChancePct`) never fires spontaneously — the only
/// modifier that appears is the one explicitly forced via
/// `debugForceModifier`, keeping these tests deterministic.
///
/// NOTE: uses pump() + explicit Durations rather than pumpAndSettle() to
/// avoid hanging on unmocked platform channels (battery_plus, audioplayers)
/// — same harness as test/screens/gotcha_game_screen_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');
  const batteryChannel =
      MethodChannel('dev.fluttercommunity.plus/battery/method');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      if (call.method == 'getVoices' || call.method == 'getLanguages') {
        return <dynamic>[];
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(batteryChannel, (call) async {
      if (call.method == 'getBatteryLevel') return 100;
      if (call.method == 'getBatteryState') return 'full';
      return null;
    });
    TtsService.instance.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(batteryChannel, null);
    TtsService.instance.resetForTesting();
  });

  testWidgets('wildcard cockpit renders and banks a turn', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('\u{1F0CF} WILDCARD'), findsOneWidget);
    expect(find.text('ROUND 1/10'), findsOneWidget);
    expect(find.text('CHAOS'), findsOneWidget);

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.totals[0], 60);
    expect(state.engineForTest.currentPlayerIndex, 1);
  });

  testWidgets(
      'first build at chaos 0 (constructor rolls no modifier) shows no '
      'announce overlay', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    expect(state.overlayKindForTest, isNull,
        reason: 'no modifier was rolled, so the null-guard in '
            '_maybeShowAnnounce must not announce anything');
  });

  testWidgets(
      'a modifier active at first build announces via the post-frame path '
      '(regression for the silently-played constructor-rolled modifier)',
      (tester) async {
    // Bug repro (2026-07-09 game log): a constructor-rolled GOLDEN DART
    // played with no announce because _maybeShowAnnounce used to run
    // synchronously in initState, before _announcer.init() had loaded the
    // TTS-enabled flag. The fix defers that first call to a post-frame
    // callback. The engine's own first roll already happened by the time
    // this test can reach it, so the ForTest seam simulates "a modifier is
    // active at first build" directly: set activeModifier, reset the
    // announce bookkeeping, then re-invoke the same post-frame path.
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    expect(state.overlayKindForTest, isNull);

    state.engineForTest.activeModifier = onlyEvens;
    state.resetAnnounceForTest();
    state.maybeAnnounceForTest();
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.overlayKindForTest, WcOverlayKind.announce);
    // The announce dialog's own "CHAOS STRIKES" caption is unique to the
    // overlay — the modifier name itself also renders in the (unrelated)
    // scorecard directive band, so asserting on that caption avoids a
    // false pass if the overlay never actually opened.
    expect(find.text('▓ CHAOS STRIKES ▓'), findsOneWidget);
    expect(find.text('ONLY EVENS'), findsAtLeastNWidgets(1));
  });

  testWidgets('bull hit opens the choice overlay; resolving moves the meter '
      'and a single undo reverts dart and meter together', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    // D-Bull -> needs a +/-3 choice.
    state.onDartHitForTest(25, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.overlayKindForTest, WcOverlayKind.bull);

    state.resolveBullForTest(3);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.chaos, 3);
    expect(state.overlayKindForTest, isNull);

    state.onUndoForTest();
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.chaos, 0);
    expect(state.engineForTest.totals[0], 0);
  });

  testWidgets(
      'a forced modifier announces on the next turn, dims its restricted '
      'segments once dismissed, and a dimmed dart scores nothing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    // Force the SECOND player's turn modifier (the very first turn's roll
    // already happened in the engine's constructor, at chaos 0 -> none).
    state.engineForTest.debugForceModifier('onlyEvens');

    // Bank player A's turn to roll (and consume) the forced modifier for B.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.currentPlayerIndex, 1);
    expect(state.overlayKindForTest, WcOverlayKind.announce);

    state.dismissOverlayForTest();
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.overlayKindForTest, isNull);
    expect(state.engineForTest.dimPredicate, isNotNull);
    expect(state.engineForTest.dimPredicate!(7, 1), isTrue);

    // A dimmed single-7 scores nothing.
    state.onDartHitForTest(7, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[1], 0);
  });

  testWidgets('board input is a no-op while an overlay is showing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    state.engineForTest.debugForceModifier('onlyEvens');
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.overlayKindForTest, WcOverlayKind.announce);

    // Dart input while the announce overlay is up must be a no-op.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.totals[1], 0);
    expect(state.engineForTest.dartsInTurn, 0);
    expect(state.overlayKindForTest, WcOverlayKind.announce);
  });

  testWidgets(
      'undoing back into a no-modifier turn and re-throwing does not '
      'suppress the next thrower\'s modifier announcement', (tester) async {
    // Regression for the announce-desync bug: _announcedTurnId used to be
    // assigned only after the "no modifier" early-return in
    // _maybeShowAnnounce, so undo (which rewinds _turnIdCounter but left a
    // stale _announcedTurnId behind) could leave the two counters
    // accidentally re-aligned on a later, DIFFERENT turn — silently
    // swallowing that turn's modifier announcement.
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    // Force B's modifier for when A's turn (no modifier) banks.
    state.engineForTest.debugForceModifier('onlyEvens');
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.currentPlayerIndex, 1);
    expect(state.overlayKindForTest, WcOverlayKind.announce);

    // Dismiss the announcement, then undo A's last dart — rewinding back
    // into A's (no-modifier) turn, past the turn boundary that triggered
    // the announcement above.
    state.dismissOverlayForTest();
    await tester.pump(const Duration(milliseconds: 50));
    state.onUndoForTest();
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.currentPlayerIndex, 0);
    expect(state.overlayKindForTest, isNull);

    // Re-force B's modifier (standing in for whatever roll would naturally
    // apply) and re-throw A's undone dart to re-bank the same turn.
    state.engineForTest.debugForceModifier('onlyEvens');
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.currentPlayerIndex, 1);
    expect(state.engineForTest.activeModifier, isNotNull);
    expect(state.overlayKindForTest, WcOverlayKind.announce);
  });

  testWidgets(
      'a joker hit chains into a forced CUT! event; dismissing both '
      'overlays clears the round', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 5),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    // startingChaos:5 carries a 30% chance (wcModifierChancePct) of rolling
    // a turn modifier for round 1's very first turn — dismiss it if it
    // showed so it doesn't block the joker dart below (input is a no-op
    // while any overlay is up).
    if (state.overlayKindForTest == WcOverlayKind.announce) {
      state.dismissOverlayForTest();
      await tester.pump(const Duration(milliseconds: 50));
    }

    final Set<int> jokers = state.engineForTest.jokers as Set<int>;
    expect(
      jokers,
      isNotEmpty,
      reason: 'wcJokerCount(5) should assign 1 joker at round 1 — got none; '
          'joker assignment or startingChaos wiring changed',
    );
    final jokerNumber = jokers.first;
    final roundBefore = state.engineForTest.round as int;

    state.engineForTest.debugForceEvent('cutEvent');
    state.onDartHitForTest(jokerNumber, 1);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.overlayKindForTest, WcOverlayKind.joker);

    state.dismissOverlayForTest();
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.overlayKindForTest, WcOverlayKind.cut);

    // Names who lost their turn this round (everyone except whoever's up
    // next — see _cutDialog's comment on why it's approximated this way).
    expect(find.textContaining('LOSES TURN'), findsOneWidget);

    state.dismissOverlayForTest();
    await tester.pump(const Duration(milliseconds: 50));

    // CUT! advances to a fresh round, whose first thrower rolls its own
    // modifier chance independently — dismiss it too if it fired, then
    // confirm the overlay chain has fully drained.
    if (state.overlayKindForTest == WcOverlayKind.announce) {
      state.dismissOverlayForTest();
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(state.overlayKindForTest, isNull);
    expect(state.engineForTest.round, greaterThan(roundBefore));
  });

  testWidgets(
      'removing the mid-turn current player advances the turn, and a '
      'roster-changed stats update completes without recording a game',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [
          Player(name: 'A', score: 0),
          Player(name: 'B', score: 0),
          Player(name: 'C', score: 0),
        ],
        config: const WildcardConfig(rounds: 1, startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    // A throws one dart, leaving their turn open (dartsInTurn == 1).
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.currentPlayerIndex, 0);

    // Remove A while they are still the current, mid-turn thrower.
    state.removePlayerForTest(0);
    await tester.pump();

    expect(state.engineForTest.currentPlayerIndex, 1,
        reason: 'removing the mid-turn current player advances to the next '
            'seat');
    expect(state.midGamePlayerChangesForTest, isTrue);

    // Roster changed -> early return: join/leave counters only, no game
    // recorded. The bar here is simply that this completes without error.
    await state.updateStatsForTest();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'every dart in one full round is attributed to that round, not the '
      'round the round-ending dart advances into', (tester) async {
    // Regression: engine.round used to be read AFTER applyDart, so the
    // round-closing dart (the last player's 3rd dart) landed in the NEXT
    // round's bucket in throwHistory — leaking one dart per round into the
    // wrong round and creating a phantom final round in KAMPDETALJER.
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    // A full round: both A and B throw a complete 3-dart turn.
    for (var i = 0; i < 6; i++) {
      state.onDartHitForTest(1, 1);
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(state.engineForTest.round, 2,
        reason: 'sanity check — the round must have advanced by the time '
            'both turns have banked');
    expect(state.throwHistoryForTest, hasLength(6));
    for (final t in state.throwHistoryForTest) {
      expect(t.roundNumber, 1,
          reason: 'every dart of round 1 (including the round-closing one) '
              'must log roundNumber 1, not the round applyDart advanced '
              'into');
    }
  });

  testWidgets(
      'removing the current player announces the seat inheritor\'s freshly '
      'rolled modifier instead of applying it silently', (tester) async {
    // Regression: the engine re-rolls a fresh modifier for the seat
    // inheritor when the removed player was the current, mid-turn thrower,
    // but the screen never announced it — mirrors Cricket's
    // announce-on-current-removal fix (R5 b44c6b3).
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [
          Player(name: 'A', score: 0),
          Player(name: 'B', score: 0),
          Player(name: 'C', score: 0),
        ],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    expect(state.engineForTest.currentPlayerIndex, 0);

    // debugForceModifier is consumed by the NEXT roll that actually
    // executes — removing the current player triggers exactly one roll (for
    // the seat inheritor), so force it right before the removal call.
    state.engineForTest.debugForceModifier('onlyEvens');
    state.removePlayerForTest(0);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.currentPlayerIndex, 1);
    expect(state.overlayKindForTest, WcOverlayKind.announce,
        reason: 'the seat inheritor\'s freshly rolled modifier must be '
            'announced, not applied silently');
  });

  // QA 2026-07-09 — the board zone used to size itself off the available
  // WIDTH (Positioned+AspectRatio), tuned to the 820x1300 design frame. On
  // shorter 16:10 tablets that overlapped the scorecard below it. The board
  // now sizes off whichever of width/height is tighter and shrinks instead.
  testWidgets(
      'on a short 16:10-class surface the board shrinks to fit and never '
      'overlaps the scorecard', (tester) async {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    final boardFinder = find.byType(DossedartX01Dartboard);
    final scorecardFinder = find.byType(DossedartWildcardScorecard);
    expect(boardFinder, findsOneWidget);
    expect(scorecardFinder, findsOneWidget);

    expect(tester.getSize(boardFinder).height, lessThanOrEqualTo(1000));
    // The scorecard's bottom edge must sit at or above the board's top edge
    // — no vertical overlap between the two zones.
    expect(
      tester.getBottomLeft(scorecardFinder).dy,
      lessThanOrEqualTo(tester.getTopLeft(boardFinder).dy + 1),
    );
  });

  testWidgets(
      'on a tall design-frame-class surface the board still renders at '
      'full width-driven size', (tester) async {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });
    // Tall enough that the Expanded board zone's available height clears
    // width - 28 even after the top bar/chaos meter/scorecard/action bar
    // chrome above and below it — i.e. genuinely width-driven, not just a
    // "tall surface" whose remaining vertical room still happens to be the
    // tighter constraint.
    tester.view.physicalSize = const Size(820, 2000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    final boardFinder = find.byType(DossedartX01Dartboard);
    final side = tester.getSize(boardFinder).width;
    // Width-driven: side ~= surface width - 28, well within the tall
    // surface's available height, so the board renders at (near) its full
    // width-class size rather than being height-clamped.
    expect(side, closeTo(820 - 28, 2));
  });

  // QA round 4: FROZEN precedence + standings chip (log-diagnosed bug — a
  // frozen player saw 'OPEN THROW · SCORE MAX' while every dart of theirs
  // scored 0).
  testWidgets(
      'FROZEN directive takes precedence over OPEN THROW when frozenPlayer '
      '== currentPlayerIndex', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    expect(state.engineForTest.currentPlayerIndex, 0);
    expect(find.text('OPEN THROW · SCORE MAX'), findsOneWidget);

    // White-box: set the field directly (a real freeze requires a joker
    // hit + forced instant event — this isolates the directive-band logic).
    state.engineForTest.frozenPlayer = 0;
    state.maybeAnnounceForTest(); // triggers a setState → rebuild only.
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('FROZEN — THIS TURN SCORES 0'), findsOneWidget);
    expect(find.text('OPEN THROW · SCORE MAX'), findsNothing);
    expect(
        find.text('Darts still count for the meter · thaws next turn'),
        findsOneWidget);
  });

  testWidgets(
      'standings show a cyan FROZEN chip for the frozen seat, distinct from '
      'the green/red event flags', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    state.engineForTest.frozenPlayer = 1;
    state.maybeAnnounceForTest();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('FROZEN'), findsOneWidget);
    final chip = tester.widget<Text>(find.text('FROZEN'));
    expect(chip.style?.color, DossedartTokens.cyan);
  });

  testWidgets(
      'a HOLY TRINITY coverage bonus banks +100 without crashing and '
      'lastBankedBonusKind is consumed (cleared) by the next dart',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 0),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    // Force B's turn modifier to HOLY TRINITY (A's first turn at chaos 0
    // already rolled none in the constructor).
    state.engineForTest.debugForceModifier('holyTrinity');
    state.onDartHitForTest(2, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(2, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(2, 1);
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.engineForTest.currentPlayerIndex, 1);
    expect(state.overlayKindForTest, WcOverlayKind.announce);
    state.dismissOverlayForTest();
    await tester.pump(const Duration(milliseconds: 50));

    // B covers 20, 5 and 1 in one turn — full trinity coverage.
    state.onDartHitForTest(20, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(5, 1);
    await tester.pump(const Duration(milliseconds: 50));
    state.onDartHitForTest(1, 1);
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(state.engineForTest.totals[1], 20 + 5 + 1 + 100);
    expect(state.engineForTest.currentPlayerIndex, 0);

    // A throws the next dart — lastBankedBonusKind must already be cleared
    // (WildcardEngine.applyDart clears it at the start of every dart).
    state.onDartHitForTest(2, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.engineForTest.lastBankedBonusKind, isNull);
  });

  testWidgets(
      'FREEZE event dialog names the frozen victim and the consequence '
      '(via the engine\'s richer detail line, names substituted)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 5),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    if (state.overlayKindForTest == WcOverlayKind.announce) {
      state.dismissOverlayForTest();
      await tester.pump(const Duration(milliseconds: 50));
    }

    final Set<int> jokers = state.engineForTest.jokers as Set<int>;
    expect(jokers, isNotEmpty);
    final jokerNumber = jokers.first;

    state.engineForTest.debugForceEvent('freeze');
    state.onDartHitForTest(jokerNumber, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.overlayKindForTest, WcOverlayKind.joker);

    state.dismissOverlayForTest();
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.overlayKindForTest, WcOverlayKind.event);

    // Both players are tied at 0 — _highestAmong resolves the tie to the
    // earliest seat, so the victim is always player A regardless of who
    // threw the joker.
    expect(find.text('A FROZEN · skipped next turn (scores 0)'),
        findsOneWidget);
  });

  testWidgets('SCORE SWAP dialog shows both players before → after',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 5),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    if (state.overlayKindForTest == WcOverlayKind.announce) {
      state.dismissOverlayForTest();
      await tester.pump(const Duration(milliseconds: 50));
    }

    final Set<int> jokers = state.engineForTest.jokers as Set<int>;
    expect(jokers, isNotEmpty);
    final jokerNumber = jokers.first;

    state.engineForTest.debugForceEvent('scoreSwap');
    state.onDartHitForTest(jokerNumber, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.overlayKindForTest, WcOverlayKind.joker);

    state.dismissOverlayForTest();
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.overlayKindForTest, WcOverlayKind.event);

    expect(find.byType(WcBeforeAfterRows), findsOneWidget);
    expect(find.textContaining('→'), findsWidgets);
  });

  testWidgets(
      'smoke: rapid darts through a forced GIFT/ROBIN HOOD/SCORE SWAP/'
      'CHAOS SURGE event chain do not crash the announce path',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WildcardGameScreen(
        players: [Player(name: 'A', score: 0), Player(name: 'B', score: 0)],
        config: const WildcardConfig(startingChaos: 5),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic state = tester
        .state<State<WildcardGameScreen>>(find.byType(WildcardGameScreen));

    if (state.overlayKindForTest == WcOverlayKind.announce) {
      state.dismissOverlayForTest();
      await tester.pump(const Duration(milliseconds: 50));
    }

    for (final eventId in [
      'chaosSurge',
      'scoreSwap',
      'robinHood',
      'gift',
    ]) {
      final Set<int> jokers = state.engineForTest.jokers as Set<int>;
      expect(jokers, isNotEmpty);
      final jokerNumber = jokers.first;

      state.engineForTest.debugForceEvent(eventId);
      state.onDartHitForTest(jokerNumber, 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.overlayKindForTest, WcOverlayKind.joker);

      state.dismissOverlayForTest();
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.overlayKindForTest, WcOverlayKind.event);

      state.dismissOverlayForTest();
      await tester.pump(const Duration(milliseconds: 50));
      if (state.overlayKindForTest == WcOverlayKind.announce) {
        state.dismissOverlayForTest();
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    expect(tester.takeException(), isNull);
  });
}
