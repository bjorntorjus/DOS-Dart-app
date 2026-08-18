# Sound folders

Every sound-event folder the app knows about, what fires it, and whether it
currently has audio files. Folders are silent no-ops until BOTH (a) files
exist in the folder and (b) the folder is declared under `flutter/assets` in
`pubspec.yaml` — this is the established convention (see `announceKill`'s doc
comment in `lib/services/game_announcer.dart`).

Status values used below:

- **har filer** — real audio files are present and the folder is declared in
  `pubspec.yaml`. Ready to go.
- **venter på filer (deklarert i pubspec)** — the folder already has a
  `pubspec.yaml` entry (so no build-file edit is needed) but currently holds
  only a `.gitkeep` placeholder. Drop files in and you're done.
- **venter på filer — udeklarert i pubspec** — a code hook plays from this
  folder, but the folder doesn't exist on disk yet and has no `pubspec.yaml`
  entry. Needs both a folder with files AND a pubspec line.

Når du legger filer i en "venter"-mappe: legg også mappen til under
flutter/assets i pubspec.yaml.

| Folder | Event | Status |
|---|---|---|
| `miss` | Dart missed the board / scored 0 | har filer |
| `miss/offensive` | Miss, offensive/meme-mode variant | venter på filer (deklarert i pubspec) |
| `win` | A player wins the match | har filer |
| `bust` | X01/Gotcha bust (moved from the old `x01/negative/out`, 2026-08-18 cleanup) | har filer |
| `checkout` | X01 checkout — layered after "`<name>` checks out!" | venter på filer — udeklarert i pubspec |
| `triple` | Triple hit flourish (chance-gated) | har filer |
| `bull` | Bullseye hit flourish (chance-gated) | venter på filer — udeklarert i pubspec |
| `slow` | Shot-clock "somling" nudge (turn running long) | venter på filer — udeklarert i pubspec |
| `nice` | "Nice" score meme (69 etc.) | venter på filer (deklarert i pubspec) |
| `six_seven` | "6-7" meme easter egg | venter på filer (deklarert i pubspec) |
| `x01/positive/end of round` | Positive end-of-round line (X01) | har filer |
| `x01/negative/end of round` | Negative end-of-round line (X01) | har filer |
| `x01/offensive/end of round` | Offensive-mode end-of-round line (X01) | venter på filer (deklarert i pubspec) |
| `x01/one_eighty` | Turn total is exactly 180 | venter på filer — udeklarert i pubspec |
| `x01/sudden_death` | Sudden death starts (`_startSuddenDeath`) | venter på filer — udeklarert i pubspec |
| `cricket/positive/end of round` | Positive end-of-round line (Cricket) | venter på filer (deklarert i pubspec) |
| `cricket/negative/end of round` | Negative end-of-round line (Cricket) | venter på filer (deklarert i pubspec) |
| `cricket/closed` | A number's 3rd own-mark lands (own close, chance-gated) | venter på filer — udeklarert i pubspec |
| `cricket/closed_all` | Player closes their last open target | venter på filer — udeklarert i pubspec |
| `around_the_clock/positive/end of round` | Positive end-of-round line (ATC) | venter på filer (deklarert i pubspec) |
| `around_the_clock/negative/end of round` | Negative end-of-round line (ATC) | venter på filer (deklarert i pubspec) |
| `around_the_clock/triple_jump` | A `countMultiples` advance of 3 steps in one dart | venter på filer — udeklarert i pubspec |
| `around_the_clock/final_target` | Player arrives at the sequence's last target | venter på filer — udeklarert i pubspec |
| `killer/hit` | Hitting another player's number (life lost) | har filer |
| `killer/death` | A player is eliminated | har filer |
| `killer/offensive/hit` | Offensive-mode hit variant | venter på filer (deklarert i pubspec) |
| `killer/offensive/death` | Offensive-mode death variant | venter på filer (deklarert i pubspec) |
| `killer/became_killer` | Player hits any own-number segment and becomes a Killer | venter på filer — udeklarert i pubspec |
| `killer/self_hit` | A Killer hits their own number (suicide rule) | venter på filer — udeklarert i pubspec |
| `halve_it/positive/end of round` | Positive end-of-round line (Splitscore) | venter på filer (deklarert i pubspec) |
| `halve_it/negative/end of round` | Negative end-of-round line (Splitscore) | venter på filer (deklarert i pubspec) |
| `halve_it/halved` | Score is halved (round target missed) | venter på filer — udeklarert i pubspec |
| `halve_it/clutch` | Last dart of the turn saves the halving | venter på filer — udeklarert i pubspec |
| `shanghai/shanghai` | Instant Shanghai (S+D+T on the round's number in one turn) | venter på filer — udeklarert i pubspec |
| `shanghai/hole_cleared` | All 3 darts hit the round's number (not an instant Shanghai) | venter på filer — udeklarert i pubspec |
| `wildcard/rewind` | A joker-fired REWIND event | venter på filer — udeklarert i pubspec |
| `wildcard/cut` | A joker-fired CUT! event | venter på filer — udeklarert i pubspec |
| `wildcard/event` | Any other joker-fired instant event (SWAP/STEAL/GIFT/…) | venter på filer — udeklarert i pubspec |
| `gotcha/kill` | A Gotcha kill lands | venter på filer — udeklarert i pubspec |
| `one_up/eliminated` | Player is eliminated | venter på filer — udeklarert i pubspec |
| `one_up/life_lost` | Player loses a life (not their last) | venter på filer — udeklarert i pubspec |
| `one_up/last_life` | Player drops to their last life (replaces `one_up/life_lost` for that beat) | venter på filer — udeklarert i pubspec |
| `one_up/target_set` | "Beat that!" — a fresh 100+ target is set | venter på filer — udeklarert i pubspec |
| `golf/ace` | Hole finished in 1 stroke | venter på filer — udeklarert i pubspec |
| `golf/birdie` | Hole finished in 2 strokes | venter på filer — udeklarert i pubspec |
| `golf/par` | Hole finished in 3 strokes | venter på filer — udeklarert i pubspec |
| `golf/bogey` | Hole finished in 4 strokes | venter på filer — udeklarert i pubspec |
| `golf/double_bogey` | Hole finished in 5 strokes | venter på filer — udeklarert i pubspec |
| `golf/triple_bogey` | Hole finished in 6 strokes | venter på filer — udeklarert i pubspec |
| `golf/sudden_death` | Regulation ends tied for 1st, playoff starts | venter på filer — udeklarert i pubspec |
