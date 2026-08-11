import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/screens/post_game/post_game_fields.dart';

void main() {
  test('x01: headline is the average, and it never enters the grid', () {
    final f = postGameFields('x01', {
      'avgTurn': 62.4,
      'highestTurn': 140,
      'darts': 24,
      'checkout': 'D20',
    });
    expect(f.headlineLabel, '3-DART AVG');
    expect(f.headlineValue, '62.4');
    expect(f.fields.map((e) => e.label), ['BEST', 'DARTS', 'CHECKOUT']);
    expect(f.fields.map((e) => e.value), ['140', '24', 'D20']);
  });

  test('declared order is preserved, not the map order', () {
    final f = postGameFields('gotcha', {
      'darts': 27,
      'score': 301,
      'busts': 2,
      'kills': 3,
      'timesKilled': 1,
      'highestTurn': 96,
    });
    expect(f.headlineValue, '301');
    expect(f.fields.map((e) => e.label),
        ['KILLS', 'KILLED', 'BUSTS', 'BEST', 'DARTS']);
  });

  test('a conditional field at zero is kept, dimmed, with an em dash', () {
    final f = postGameFields('wildcard', {
      'score': 204,
      'jokersHit': 1,
      'windowPrizes': 0,
      'pointsStolen': 0,
      'highestTurn': 60,
      'darts': 27,
    });
    final stolen = f.fields.firstWhere((e) => e.label == 'STOLEN');
    expect(stolen.isZero, isTrue);
    expect(stolen.value, '—');
    expect(f.fields.length, 5, reason: 'geometry must not change at zero');
  });

  test('an absent stat is skipped — absent is not zero', () {
    final f = postGameFields('x01', {'avgTurn': 40.0, 'highestTurn': 100});
    expect(f.fields.map((e) => e.label), ['BEST']);
  });

  test('golf folds vs-par into the headline value', () {
    final f = postGameFields('golf', {'strokes': 54, 'vsPar': 3});
    expect(f.headlineLabel, 'STROKES');
    expect(f.headlineValue, '54 (+3)');
  });

  test('killer is headline-only and yields an empty grid', () {
    final f = postGameFields('killer', {'lives': 2});
    expect(f.headlineValue, '2');
    expect(f.fields, isEmpty);
  });

  test('an unknown mode degrades to an empty headline rather than throwing',
      () {
    final f = postGameFields('nope', {});
    expect(f.headlineValue, '—');
    expect(f.fields, isEmpty);
  });

  test('every mode declares a headline for its own stat shape', () {
    // Guards the switch against a mode being forgotten: each of the ten
    // gameMode keys the screens actually pass must resolve to a real
    // headline, not the unknown-mode fallback.
    const shapes = {
      'x01': {'avgTurn': 50.0},
      'cricket': {'points': 42},
      'aroundTheClock': {'reached': 14},
      'killer': {'lives': 2},
      'halveIt': {'score': 300},
      'gotcha': {'score': 301},
      'oneUp': {'livesLost': 1},
      'golf': {'strokes': 54, 'vsPar': 0},
      'shanghai': {'score': 120},
      'wildcard': {'score': 412},
    };
    for (final entry in shapes.entries) {
      final f = postGameFields(entry.key, entry.value);
      expect(f.headlineValue, isNot('—'), reason: entry.key);
      expect(f.headlineLabel, isNotEmpty, reason: entry.key);
    }
  });
}
