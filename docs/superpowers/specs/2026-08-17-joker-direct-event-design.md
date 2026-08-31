# Joker Direct-to-Event Flow — Design

**Date:** 2026-08-17 · **Status:** Approved (Bjørn: «det ser fint ut»)

## Problem

A joker hit currently shows TWO dialogs with a tap each: first «JOKER! ·
HIDDEN NUMBER n DETONATES», then the instant-event dialog. Tester feedback
(2026-08-14): it reads as a full stop — «joker, trykk, beskjed». Wanted:
joker → the message about what happens, directly.

## Design

1. `_routeDartResult` (wildcard_game_screen.dart): when `result.jokerHit !=
   null` AND `result.instantEvent != null`, skip the joker overlay — log the
   event (the logging block moves out of `_onJokerDismiss` into a shared
   helper), set the overlay directly to `_overlayKindForEvent(event)`, and
   announce `'Joker!'` followed by `_announceEvent(event)` (TTS queues them).
   `_pendingResult` stays set for the event dismiss, exactly as today.
2. The three event dialogs (`_eventDialog`, `_cutDialog`, `_rewindDialog`)
   render a shared compact header line at the top when
   `_pendingResult?.jokerHit != null`: `🃏 JOKER · HIDDEN NUMBER n`
   (VT323, DossedartTokens.green accent) — so the joker reveal and the
   outcome are ONE dialog, ONE dismissing tap.
3. Joker WITHOUT an instant event (defensive — the engine draws an event on
   every joker today): keep today's plain JOKER! dialog via
   `WcOverlayKind.joker`; `_onJokerDismiss` shrinks to that fallback path.
4. Unchanged: bull-choice (a real decision), the modifier announce overlay,
   the one-word TTS stings for CUT!/REWIND, all engine logic.

## Testing

Screen tests (wildcard_game_screen_test.dart): every test that steps
joker → dismiss → event is rewritten to expect the direct jump (overlay is
the event kind right after the joker dart) and the `JOKER · HIDDEN NUMBER`
header inside the event dialog. The REWIND delta/NOT THROWN assertions and
CUT! loses-turn assertions stay as-is behind the new single step.

## Out of scope

Auto-dismiss timers (rejected — players control the pace, REWIND/CUT rows
must stay readable). The announce overlay's own flow.
