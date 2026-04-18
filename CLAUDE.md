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

Mørkt tema med grønn (#43A047) primær og rød (#E53935) sekundær.

## Språk

- Kode og kommentarer: **Engelsk**
- UI-tekst: **Engelsk**
- Kommunikasjon med utvikler: **Norsk**

## Konvensjoner

- Nye spillmoduser følger mønsteret til eksisterende (egen screen + config-subclass)
- Lydfiler organisert under `assets/sounds/<modus>/<hendelse>/`
- Undo-funksjonalitet via undo-stacks i game screens
