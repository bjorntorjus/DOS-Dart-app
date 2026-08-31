import 'season.dart';

/// A named, manually bounded rating event — a party night rated on its own
/// 1200-reset table so the quarterly season is untouched.
///
/// Swap-and-snapshot: [savedRatings] holds every player's season rating as it
/// stood when the event started; EventService writes 1200 into `player.rating`
/// for the duration and restores from here at the end. See
/// `docs/superpowers/specs/2026-08-25-event-mode-design.md`.
class EventRecord {
  const EventRecord({
    required this.id,
    required this.name,
    required this.start,
    this.end,
    required this.savedRatings,
    this.rows = const [],
  });

  final String id;
  final String name;
  final DateTime start;

  /// Null while the event is open.
  final DateTime? end;

  /// Season ratings put aside at start, by player id. Players created during
  /// the event are absent and restore to 1200 — which is their untouched
  /// season rating anyway.
  final Map<String, double> savedRatings;

  /// Final table. Empty while open; [SeasonPlayerRow] is reused as-is, its
  /// `qualified` getter is simply never consulted for events.
  final List<SeasonPlayerRow> rows;

  bool get isOpen => end == null;

  /// Everyone with at least one game, best rating first, ties on name. No
  /// qualifying threshold — Bjørn's call: one sick game is allowed to send
  /// you to the sky, and everyone knows one game is not the whole picture.
  List<SeasonPlayerRow> get ranked {
    final out = rows.where((r) => r.games > 0).toList()
      ..sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        return byRating != 0 ? byRating : a.name.compareTo(b.name);
      });
    return out;
  }

  String? get winnerName => ranked.isEmpty ? null : ranked.first.name;

  EventRecord copyWith({DateTime? end, List<SeasonPlayerRow>? rows}) =>
      EventRecord(
        id: id,
        name: name,
        start: start,
        end: end ?? this.end,
        savedRatings: savedRatings,
        rows: rows ?? this.rows,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'start': start.toIso8601String(),
        if (end != null) 'end': end!.toIso8601String(),
        'savedRatings': savedRatings,
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  factory EventRecord.fromJson(Map<String, dynamic> json) => EventRecord(
        id: json['id'] as String,
        name: json['name'] as String,
        start: DateTime.parse(json['start'] as String),
        end: json['end'] == null ? null : DateTime.parse(json['end'] as String),
        savedRatings: (json['savedRatings'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        rows: ((json['rows'] as List?) ?? const [])
            .map((r) => SeasonPlayerRow.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

/// What an event close hands the achievement evaluator: one player's row plus
/// the context that only makes sense across events.
class EventStanding {
  const EventStanding({
    required this.event,
    required this.row,
    required this.rank,
    required this.eventsWon,
    required this.isFirstEvent,
    required this.seasonRatingAtStart,
  });

  final EventRecord event;
  final SeasonPlayerRow row;

  /// 1-based place. Everyone with a game is ranked, so never null.
  final int rank;

  /// Events this player has won, this one included.
  final int eventsWon;

  /// No row in any earlier closed event.
  final bool isFirstEvent;

  /// The season rating put aside when the event started, or null when the
  /// player was created during the event.
  final double? seasonRatingAtStart;
}
