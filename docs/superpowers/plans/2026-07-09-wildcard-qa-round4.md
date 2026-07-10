# WILDCARD QA Round 4 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the 2-player GIFT bug and the misleading FROZEN turn UI (both log-diagnosed), rework DOUBLE TROUBLE (+ sibling TRIPLE THREAT), restore/standardize TTS per Bjørn's spec, and run the event-info audit so every event explains itself on screen.

## Global Constraints (locked with Bjørn 2026-07-09)

- **Branch:** `feat/wildcard-qa3` off `feat/wildcard-qa2` tip (post-1.13.0).
- **GIFT fix:** target = lowest total INCLUDING the hitter (tie → earliest seat). If the hitter is last, the gift lands on themselves (no-op redirect — spec-true "the player in last place"). The 13:12 log showed 2-player GIFT handing points to the LEADER (locked #10's "among others" was wrong).
- **FROZEN UX:** directive-band precedence becomes frozen > window > modifier > open: `WcDirective(icon '🧊', color cyan, head 'FROZEN — THIS TURN SCORES 0', sub 'Darts still count for the meter · thaws next turn')`. Standings: frozen player gets a `FROZEN` flag chip (cyan) while the flag is set. The FREEZE event dialog detail must name the victim AND the consequence ('P0 is frozen — their next turn scores 0').
- **DOUBLE TROUBLE v2 (id/name kept):** ONLY the double ring scores — per-ring dims `(s, m) => m != 2`; a double scores `segment × 5` (D20 = 100). Desc: 'Only doubles score — and they pay ×5'. Bull EXEMPT as usual (S-Bull 25/D-Bull 50 + chaos choice; NOT ×5, not dimmed — bull is its own lever; only trinity overrides bull).
- **NEW modifier TRIPLE THREAT** (id `tripleThreat`, severity medium, icon 🎯-adjacent e.g. ⚡): ONLY the triple ring scores — dims `(s, m) => m != 3`; a triple scores `segment × 5` (T20 = 100). Desc: 'Only triples score — and they pay ×5'. Same bull exemption. (Named to avoid the existing X01 achievement 'TREBLE TROUBLE'.) Enters the severity pool as medium.
- **Meter note:** the double +1 / triple +2 meter movement still applies under these modifiers (meter follows the dart).
- **TTS spec (Bjørn's exact ask — applies to WILDCARD; other modes already do this):** (1) next-player announcements RESTORED in wildcard; (2) per-dart announcement of the REGISTERED points (the effective value — a dimmed T20 says '0', a DOUBLE TROUBLE D20 says '100'); (3) event/modifier stings stay (name only pre-turn); (4) joker sting stays; (5) event OUTCOME lines with numbers where meaningful: trinity completion → '1, 20, 5 — plus 100!', WINDOW prize (exists), GIFT → '<n> points gifted to <name>', ROBIN HOOD → '50 stolen from <name>', SCORE SWAP → '<A> and <B> swap scores', FREEZE → '<name> is frozen next turn', CHAOS SURGE → 'Chaos plus 3'. CURSED stays number-secret ('A number is cursed'). No settings toggle (not requested).
- **Event-info audit (screen):** every instant-event dialog shows name + victim/beneficiary + amounts via lastEventResolution (engine details already carry indices→the screen maps names; AUDIT all 9 and fill gaps); FREEZE gets the persistent directive/standings treatment above; CURSED existence may be visible, the number never.
- **Diagnostics:** GameLogger logs modifiers rolled (`MODIFIER <name> for P<i>`), instant events (`EVENT <name> <detail>`), bull choices (`BULL_CHOICE ±n`), and TtsService logs utterance COMPLETION (`TTS done "<text>"`) so the next field log distinguishes enqueued from audible.
- All strings English; tokens only; pump+Duration; fixers stage only edited files; docs via Edit tool. Baseline 641 tests. Version 1.14.0 (three sites) + APK at the end.

## Tasks

### Task 0: Branch
- [ ] `git checkout feat/wildcard-qa2 && git checkout -b feat/wildcard-qa3`; analyze clean; 641 green.

### Task 1: Data layer — DOUBLE TROUBLE v2 + TRIPLE THREAT
`lib/models/wildcard_events.dart` + tests. DT def: dims `(s,m) => m != 2` (any segment, ring-based!), desc 'Only doubles score — and they pay ×5'. NEW tripleThreat def (medium) dims `(s,m) => m != 3`, desc 'Only triples score — and they pay ×5', added to wcModifiers. Tests: DT dims (20,1) true /(20,2) false /(20,3) true; TT mirror; pool sizes updated (16→17 modifiers, medium count +1). NOTE: bull is NOT handled by dims here (engine exemption covers it — the defs' predicates are never consulted for 25 except under trinity; assert in a comment).
- [ ] Commit `feat(wildcard): DOUBLE TROUBLE v2 (doubles-only ×5) + TRIPLE THREAT`

### Task 2: Engine — ×5 scoring, GIFT fix, event details, logging hooks
`lib/models/wildcard_engine.dart` + tests.
- Scoring: under DT, a double-ring dart (segment 1–20, m==2) scores `segment*5`; under TT, triple scores `segment*5`; other rings 0 via dims (already generic). Remove the old DT branch (doubles×3/triples-0).
- GIFT target: lowest total including the hitter (tie → earliest seat); hitter-is-last → redirect to self (points bank normally); detail line reflects the real target.
- lastEventResolution details audit (engine side): every event's detail names indices + amounts (FREEZE: 'P<i> is frozen — their next turn scores 0'; GIFT: '<n>... ' amounts computed at bank — restructure: gift detail finalized at BANKING with the actual amount, or the dialog shows 'rest of the turn goes to P<i>' at fire time — keep fire-time phrasing simple + add the banked amount to a NEW small result surface if cheap; else fire-time only, documented).
- Trinity completion outcome: engine exposes on the result or a field that the turn banked the trinity bonus (e.g. `lastBankBonus`/reuse windowPrizes-style counter) so the screen can announce '1, 20, 5 — plus 100!'. Simplest: `GotchaDartResult`-style — add `bool trinityCompleted` to the bank info the screen can read post-turn (`lastTurnBankedBonus`? implementer picks minimal, snapshot-safe).
- Tests: DT D20→100, S20→0, T20→0, bull→25+choice; TT T20→100, D20→0; GIFT 2-player self-gift (hitter last keeps own points), 3-player real target incl. hitter-comparison; details digit/name assertions; snapshot audit for any new field.
- [ ] Commit `feat(wildcard): x5 ring modifiers, GIFT targets true last place, richer event details`

### Task 3: Screen — FROZEN state, TTS restoration, event dialogs, logging
`lib/screens/wildcard_game_screen.dart` (+ `game_announcer.dart` if a helper is needed, `game_logger.dart`, `tts_service.dart` for completion logging) + tests.
- Directive precedence frozen > window > modifier > open (build from `engine.frozenPlayer == engine.currentPlayerIndex`).
- Standings FROZEN chip (flagText 'FROZEN', cyan → flagGood semantics: use a neutral/cyan variant — check WcStandingEntry's flagGood bool; extend minimally if two colors insufficient).
- TTS: restore announceNextPlayer at turn end; per-dart announce of REGISTERED points (`result.points` — '0' spoken on dimmed); event outcome lines per the locked table (names via players[]); trinity completion announce; FREEZE dialog + TTS name the victim & consequence.
- Logging: logModifier/logEvent/logBullChoice calls (GameLogger API additions, style-matched); TtsService completion log line.
- Tests: frozen directive shows when frozenPlayer == current (white-box field set); dialog detail mapping for GIFT/FREEZE with player NAMES; smoke: announces don't crash under rapid hooks.
- [ ] Commit `feat(wildcard): FROZEN turn state, restored TTS, event outcomes spoken, event logging`

### Task 4: Spec v1.3 + verification + review + APK
- Spec (Edit tool): §4 DT v2 row + TRIPLE THREAT row (17 modifiers), §5 GIFT wording ('player in last place — including the hitter'), FREEZE UI note, §9 TTS spec, §10 bull-under-DT/TT note; status line v1.3.
- analyze 0; full suite green; whole-branch fable review; fix Criticals/Importants; version 1.14.0 (pubspec + BOTH home screens) + APK.

## Self-review notes
- DT/TT dims are RING-based (multiplier), a new dims flavor — the per-ring board dimming already supports it (band-level predicates); the double ring will be the only lit band → strong visual.
- GIFT self-gift = points bank normally (redirect target == thrower) — must not double-bank; trace the redirect path.
- 'TRIPLE THREAT' avoids the X01 achievement name 'TREBLE TROUBLE' (uniqueness rule is for achievements, but avoiding player confusion).
- No TTS settings toggle — Bjørn specified one behavior, not options (no unrequested features).
