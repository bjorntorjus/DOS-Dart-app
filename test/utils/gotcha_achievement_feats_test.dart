import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/achievement_event.dart';
import 'package:dart_scoring/utils/gotcha_achievement_feats.dart';

void main() {
  group('gotchaEventsFromKillLog', () {
    test('double tap: same pair twice in one round → attacker event', () {
      final log = [
        (round: 2, attacker: 1, victim: 0),
        (round: 2, attacker: 1, victim: 0),
      ];
      expect(gotchaEventsFromKillLog(log)[1],
          contains(AchievementEvent.gotchaDoubleTap));
    });

    test(
        'pinata: two different attackers, same victim, same round → victim event only',
        () {
      final log = [
        (round: 0, attacker: 1, victim: 0),
        (round: 0, attacker: 2, victim: 0),
      ];
      final ev = gotchaEventsFromKillLog(log);
      expect(ev[0], contains(AchievementEvent.gotchaPinata));
      expect(ev[1] ?? const [],
          isNot(contains(AchievementEvent.gotchaDoubleTap)));
    });

    test('vendetta: same pair rounds 3 and 4 → attacker; victim gets crash dummy',
        () {
      final log = [
        (round: 3, attacker: 2, victim: 1),
        (round: 4, attacker: 2, victim: 1),
      ];
      final ev = gotchaEventsFromKillLog(log);
      expect(ev[2], contains(AchievementEvent.gotchaVendetta));
      expect(ev[1], contains(AchievementEvent.gotchaCrashDummy));
    });

    test('non-consecutive rounds do not trigger streak events', () {
      final log = [
        (round: 1, attacker: 2, victim: 1),
        (round: 3, attacker: 2, victim: 1),
      ];
      final ev = gotchaEventsFromKillLog(log);
      expect(ev[2] ?? const [],
          isNot(contains(AchievementEvent.gotchaVendetta)));
    });

    test('events dedupe: pair hit twice in each of two rounds lists each event once',
        () {
      final log = [
        (round: 2, attacker: 1, victim: 0),
        (round: 2, attacker: 1, victim: 0),
        (round: 3, attacker: 1, victim: 0),
        (round: 3, attacker: 1, victim: 0),
      ];
      final ev = gotchaEventsFromKillLog(log);

      expect(
        ev[1],
        containsAll(<AchievementEvent>[
          AchievementEvent.gotchaDoubleTap,
          AchievementEvent.gotchaVendetta,
        ]),
      );
      expect(ev[1]!.length, 2);

      expect(
        ev[0],
        containsAll(<AchievementEvent>[
          AchievementEvent.gotchaPinata,
          AchievementEvent.gotchaCrashDummy,
        ]),
      );
      expect(ev[0]!.length, 2);
    });

    test('empty log → empty map', () {
      expect(gotchaEventsFromKillLog(const []), isEmpty);
    });
  });
}
