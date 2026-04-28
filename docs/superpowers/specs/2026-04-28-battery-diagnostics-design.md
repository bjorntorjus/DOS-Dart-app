# Battery Diagnostics — Design Spec

**Date:** 2026-04-28
**Status:** Approved (pending plan)
**Author:** Bjørn + Claude (superpowers:brainstorming)

## Problem

The Dart Scoring App is suspected to drain ~10% battery per game (~30 min) on an older Samsung tablet. We have no data on where the power goes — screen, CPU, audio pipeline, the `GameLogger` itself, or something else. Static review of the codebase found no obvious smoking guns (`shouldRepaint => false` on the dartboard, no `Timer.periodic`, no `wakelock`, single pooled `AudioPlayer` and `FlutterTts`).

We need measurement before optimization.

## Goal

Instrument the app so a single test game produces a log file that reveals battery-drop rate over time, correlated with in-game events. Use the existing log share mechanism so no new infrastructure is needed.

## Non-Goals

- Battery temperature sampling (dropped — `battery_plus` does not expose it; would require a platform channel for one extra datapoint)
- Performance optimizations themselves — this spec only adds diagnostics. Optimization is a follow-up project driven by what the data reveals.
- Continuous battery monitoring outside of active games

## Architecture

```
Game screens ──(existing log calls)──► GameLogger (extended)
                                           │
                BatterySampler (NEW) ──────┤  writes to
                                           ▼
                            game_log_YYYY-MM-DD.txt
                                           │
                                           ▼
                       Existing share button in Settings
```

Single new singleton (`BatterySampler`) that starts when a game begins and stops when it ends. Writes battery samples through the existing `GameLogger` to the same daily log file. A new `LogMode` setting controls the verbosity of `GameLogger` itself, enabling A/B testing of whether the logger is contributing to drain.

## Components

### New: `lib/services/battery_sampler.dart` (~80 lines)
- Singleton, same pattern as `GameLogger`
- `start(String gameMode)` — called from game screen `initState`
- `stop()` — called on dispose / post-game transition
- Internal `Timer.periodic(Duration(seconds: 30))` reads battery level + state via `battery_plus`, writes through `GameLogger.logBattery(...)`
- Defensive: on API failure, log once and stop trying — never crash a game
- Timer is ONLY active during games, never globally

### New dependency: `battery_plus`
Official Flutter community plugin, low overhead, no known leaks.

### Extended: `lib/services/game_logger.dart`
- New enum `LogMode { full, minimal, off }`
- Read from `AppSettings` on init; cached
- In each `logXxx` method: gate by mode (`minimal` allows only battery events; `off` writes nothing)
- New method `logBattery(int level, String state)`

### Extended: `lib/services/app_settings.dart`
- New key `log_mode` (string, default `"full"`)

### Extended: `lib/screens/settings_screen.dart`
- New "Debug" section with 3-way radio: Full / Minimal / Off
- Existing "send log" button unchanged

### Touched: each game screen (`x01`, `cricket`, `around_the_clock`, `killer`, `halve_it`)
- `BatterySampler.instance.start(gameMode)` in `initState`
- `BatterySampler.instance.stop()` in `dispose`

## Log Format

```
[14:32:01.000] === GAME START: Cricket, 4 players, log_mode=full ===
[14:32:01.005] BATTERY: level=87%, state=discharging
[14:32:31.002] BATTERY: level=87%, state=discharging
[14:32:43.118] DART: P1 (Bjørn) hit T20 (3 marks)
[14:33:01.005] BATTERY: level=86%, state=discharging
...
[15:02:14.000] === GAME END: winner=P1, duration=30:13 ===
```

## A/B Test Protocol

1. **Game 1:** `log_mode = full`, play a normal Cricket game ~30 min, send log.
2. **Game 2:** `log_mode = minimal`, play a comparable Cricket game ~30 min, send log.
3. Compare battery drop per minute between the two logs.

**Interpretation:**
- Game 2 drops noticeably less → `GameLogger` is a meaningful contributor → optimize logging first (batch writes, async, prune call-sites).
- Roughly equal → `GameLogger` is innocent → use the event timeline in Game 1 to find which events (sound, TTS, video, round transitions) correlate with drops.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| New `Timer.periodic` itself contributes to drain | Active only during games; off when game ends |
| `battery_plus` plugin overhead | Negligible per published benchmarks; sampling at 30s makes it irrelevant |
| Forgot to call `stop()` on some exit path | `dispose()` in each game screen guarantees stop on all teardown paths |
| Log file grows large with battery samples | 60 extra lines per 30-min game; existing 5-day rotation handles it |

## Out of Scope (Future Work)

- Optimizations driven by what the diagnostics reveal — separate spec
- Temperature sampling via platform channel — only if battery delta is inconclusive
- `setState`-counter instrumentation — only if logger and obvious events are ruled out
