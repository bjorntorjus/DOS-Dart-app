import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/models/saved_player.dart';

void main() {
  test('archived round-trips through JSON and defaults false on legacy payloads',
      () {
    final p = SavedPlayer(id: 'a', name: 'A', createdAt: DateTime(2026, 1, 1))
      ..archived = true;
    final restored = SavedPlayer.fromJson(p.toJson());
    expect(restored.archived, isTrue);

    final legacy = p.toJson()..remove('archived');
    expect(SavedPlayer.fromJson(legacy).archived, isFalse);
  });
}
