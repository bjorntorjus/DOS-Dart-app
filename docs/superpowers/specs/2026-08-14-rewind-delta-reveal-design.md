# REWIND Delta Reveal — Design

**Date:** 2026-08-14 · **Status:** Approved (mockup OK'd by Bjørn)

## Problem

The REWIND dialog shows `NAME before → after` but not the deviation, and does
not distinguish players who had already thrown this round from those who had
not (tester feedback 2026-08-14).

## Design

1. `WcRevealRow` gains `bool hasThrown` (default `true`). Rendering in
   `_RevealRow` (dossedart_wildcard_dialogs.dart):
   - `hasThrown`: `NAME  before → after  <delta>` where delta = after − before,
     rendered as a trailing chip: green `+N` when positive, red `−N` when
     negative, dim `±0` when zero. Colors from `DossedartTokens.green/red`,
     the `±0` in white at low alpha (matches existing white54/white70 usage).
   - `!hasThrown`: whole row dimmed (Opacity), shows `NAME  before` and a
     `NOT THROWN` tag instead of the arrow/after/delta.
2. REWIND dialog (`wildcard_game_screen.dart`): stash the joker-thrower's seat
   in `_onDartHit` BEFORE `applyDart` reseats `currentPlayerIndex` (same
   pattern and reason as `_cutThrowerSeat`). Rotation is ascending active-seat
   order, so `hasThrown = seat <= throwerSeat` for the active seats in
   `scoreChanges`. The engine already reports the thrower's true loss
   including the unbanked in-progress turn.
3. SCORE SWAP / ROBIN HOOD reveal rows (event dialog) reuse the delta chip
   automatically (`hasThrown` stays true there).
4. TTS unchanged (REWIND keeps its one-word sting — QA round 4 binding spec).

## Testing

- Widget tests (dossedart_wildcard_dialogs_test.dart): negative delta red,
  positive delta green, zero delta `±0`, `hasThrown: false` → dimmed row with
  `NOT THROWN` and no arrow.
- Screen-level: rewind rows mark seats after the thrower as not-thrown
  (reuse whatever forcing hook existing wildcard screen tests use, if any).

## Out of scope

DIVIDE BY THREE stays value-based (Bjørn 2026-08-14). Log format unchanged.
