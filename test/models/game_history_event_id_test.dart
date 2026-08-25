import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/game_history.dart';

void main() {
  GameHistoryEntry entry({String? eventId}) => GameHistoryEntry(
        id: '1',
        gameMode: 'x01',
        date: DateTime(2026, 8, 25, 20),
        players: [
          GameHistoryPlayer(
              name: 'Ada', savedPlayerId: 'a', placement: 1, stats: const {}),
        ],
        eventId: eventId,
      );

  test('eventId round-trips through JSON', () {
    final json = jsonDecode(jsonEncode(entry(eventId: 'evt_1').toJson()));
    final back = GameHistoryEntry.fromJson(json as Map<String, dynamic>);
    expect(back.eventId, 'evt_1');
  });

  test('a season game has no eventId and writes no key', () {
    final json = entry().toJson();
    expect(json.containsKey('eventId'), isFalse);
    expect(GameHistoryEntry.fromJson(json).eventId, isNull);
  });

  test('pre-event history without the key decodes to null', () {
    final json = entry().toJson()..remove('eventId');
    expect(GameHistoryEntry.fromJson(json).eventId, isNull);
  });
}
