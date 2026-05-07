# Dart Scoring App

Flutter-app for poengberegning i dart. Hovedsakelig et hobbyprosjekt.

## Spillmoduser

- **X01** (301/501/701) — nedtelling med double-out
- **Cricket** — marks/poeng på 15-20 + Bull
- **Around the Clock** — treffe 1-20 i rekkefølge
- **Killer** — velg tall, eliminer motstandere
- **Halve It** — treff mål eller halver poengsummen

## Arkitektur

```
lib/
  models/       — datamodeller (GameConfig, SavedPlayer, DartThrow, etc.)
  screens/      — skjermer (home, player_setup, game screens, post_game, stats, settings)
  services/     — singleton-tjenester (GameAnnouncer, TtsService, SoundService, etc.)
  widgets/      — gjenbrukbare UI-komponenter
  utils/        — hjelpefunksjoner (player_colors)
  data/         — statiske data (checkout-tabell for X01)
```

- **State management:** Lokal StatefulWidget-state, ingen ekstern pakke
- **Persistering:** SharedPreferences via PlayerStorage og AppSettings
- **Tjenester:** Singleton-instanser (GameAnnouncer, SoundService, TtsService)
- **Modeller:** Sealed classes for GameConfig, extensions for enum-labels

## Viktige tjenester

- `GameAnnouncer` — orkestrerer lyd + TTS for spillhendelser
- `SoundService` — købasert lydavspilling med audioplayers
- `TtsService` — text-to-speech med kø og idle-callbacks
- `MemeService` — easter eggs (69, sekvenser, høye scores)
- `VideoService` — MP4-overlays på spesielle hendelser
- `EloService` — rating-beregninger
- `StatsRecorder` — statistikk per modus, H2H, rating-historikk

## Tema

Mørkt tema, M3 (`useMaterial3: true`). Paletten er låst til fire roller — alle nye komponenter MÅ velge fra disse:

| Rolle       | Hex       | Når                                                     |
| ----------- | --------- | ------------------------------------------------------- |
| `primary`   | `#43A047` | Primær handling, aktiv spiller, positiv endring         |
| `secondary` | `#FFA726` | Sekundær handling, finished/out, soft warning           |
| `tertiary`  | `#FFD54F` | Informasjon, achievements, checkout-tips                |
| `error`     | `#E53935` | Bust, destructive, negativ endring                      |

Bruk alltid `Theme.of(context).colorScheme.<role>` — ikke `Colors.amber` / `Colors.orange` / hex literals.

**Unntak (kun disse):**
- `lib/utils/player_colors.dart` — avatar-farger, separat palett
- `lib/widgets/heatmap_board.dart` — data-viz gradient
- D-knapper i score-input (`Colors.orange[800]` i halve_it/atc) — funksjonell input-semantikk for double
- Bronze (`Colors.brown[300]`) for 3.-plass — ikke i role-palette, kun en literal

Full spec: `docs/superpowers/specs/2026-04-30-color-design-system.md`.

## Språk

- Kode og kommentarer: **Engelsk**
- UI-tekst: **Engelsk**
- Kommunikasjon med utvikler: **Norsk**

## Konvensjoner

- Nye spillmoduser følger mønsteret til eksisterende (egen screen + config-subclass)
- Lydfiler organisert under `assets/sounds/<modus>/<hendelse>/`
- Undo-funksjonalitet via undo-stacks i game screens
