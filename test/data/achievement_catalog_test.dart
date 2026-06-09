import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/data/achievement_catalog.dart';
import 'package:dart_scoring/models/achievement.dart';

void main() {
  final catalog = achievementCatalog;

  test('catalog is non-empty', () {
    expect(catalog.length, greaterThan(40));
  });

  test('ids are unique', () {
    final ids = catalog.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'duplicate achievement id');
  });

  test('names are unique (no parenthetical mode-dupes)', () {
    final names = catalog.map((a) => a.name).toList();
    expect(names.toSet().length, names.length, reason: 'duplicate achievement name');
    for (final n in names) {
      expect(n.contains('('), isFalse, reason: 'name "$n" uses a parenthetical');
    }
  });

  test('every badge is milestone XOR event', () {
    for (final a in catalog) {
      final hasMilestone = a.milestoneTest != null;
      final hasEvent = a.event != null;
      expect(hasMilestone ^ hasEvent, isTrue,
          reason: '${a.id} must be exactly one of milestone/event');
    }
  });

  test('every mode value is a known game-mode key', () {
    const known = {
      'x01', 'cricket', 'cricket_cutthroat', 'aroundTheClock',
      'killer', 'halveIt', 'shanghai',
    };
    for (final a in catalog.where((a) => a.mode != null)) {
      expect(known.contains(a.mode), isTrue, reason: '${a.id} mode ${a.mode}');
    }
  });

  test('every glyph resolves to an icon (wave 1)', () {
    for (final a in catalog) {
      expect(a.glyph.icon, isNotNull, reason: '${a.id} missing icon glyph');
    }
  });
}
