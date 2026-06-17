# Spillerprofil — utvidet (PROFIL-fanen i DOSSEDART stats)

**Dato:** 2026-06-17
**Status:** Design godkjent som v1 (mockup) — klar for implementeringsplan
**Mockup:** `docs/design/profile-redesign/dossedart-profile-mockup.html`
**Kontekst:** Bygger på den eksisterende `DossedartStatsScreen` PROFIL-fanen. Additivt — ingen
ny lagring. Henger sammen med parkert 4-fane-restrukturering (`project_stats_restructure_pending`)
men er uavhengig av den.

## Mål

PROFIL-fanen stopper i dag ved: hero (avatar/ELO/rank/win-ring), rating-graf, winrate per modus,
H2H topp-4, prestasjoner. Dette legger til **fire nye seksjoner** (alle bygget på data vi allerede
lagrer): **Form**, **Streaks & rating-topp**, **Rekorder**, og **per-modus dybde**.

## Seksjonsrekkefølge (PROFIL, topp→bunn)

1. Spiller-velger (uendret)
2. **Hero** — utvidet: legg til «N kamper · siden <mnd år>» (`gamesPlayed`, `createdAt`)
3. **FORM · siste 8** (ny)
4. **STREAKS & TOPP** (ny)
5. **RATING-HISTORIKK** — grafen (uendret, `_RatingSparkline`)
6. **REKORDER / PB** (ny)
7. **PER MODUS** — utvidet fra winrate-rad til winrate-bar + nøkkeltall
8. **HEAD-TO-HEAD** — uendret + «nemesis»-merke
9. **PRESTASJONER** (uendret)

## Datakilder — eksakt mapping (verifisert mot kode 2026-06-17)

### FORM · siste 8
`GameHistoryService.load()` → siste N kamper der spilleren deltok (match på `savedPlayerId`).
Per kamp: resultat (W/L/U) utledet av spillerens `placement` mot beste plassering i den kampen
(delt 1.-plass = U); ΔELO = `GameHistoryPlayer.ratingDelta`. Pip: grønn W / rød L / gul U + ΔELO.

### STREAKS & TOPP
- Nå på rad: `SavedPlayer.currentWinStreak` (eller `currentLossStreak` hvis i tap-rekke).
- Beste streak: `bestWinStreak`.
- Rating-topp: `max(ratingHistory.rating)`.
- Beste rank: `min(ratingHistory.placement)` (lavest = best; null-safe).

### REKORDER / PB (fra `modeStats[mode].counters`, kun `max:`-tellere = ekte career-PB)
| Tile | Teller | Status |
|------|--------|--------|
| X01 høyeste runde | `max:highestTurn` | ✅ finnes |
| X01 beste checkout | `max:bestCheckout` | ✅ finnes |
| Cricket beste poeng | `max:bestPoints` | ✅ finnes |
| Shanghai beste score | `max:bestScore` | ✅ finnes |
| Splitscore beste score | `max:bestScore` | ✅ finnes |
| Splitscore største halvering | `max:biggestHalving` | ✅ finnes |
| Killer kills totalt | `kills` (kumulativ) | ✅ finnes (career-total, ikke flest-i-én-kamp) |
| ATC treff-rate | `totalHits / totalDarts` | ✅ derivert |

Vis kun tiles der spilleren har spilt modusen (telleren > 0). Tom modus = utelat tile.

### PER MODUS (utvidet)
Per modus med `played > 0`: winrate-bar (`won/played`) + 2–4 nøkkeltall:
- X01: snitt (`totalTurnScore/totalTurns`), best (`max:highestTurn`), 100+ (`turnsOver100`), checkout (`max:bestCheckout`)
- Cricket: MPR (`marksScored/(totalDarts/3)`), beste poeng (`max:bestPoints`), lukket (`closedTargets`)
- ATC: treff-rate (`totalHits/totalDarts`), fullført (`finished`)
- Shanghai: beste score (`max:bestScore`), snitt (`totalScore/totalGames`)
- Splitscore: beste score (`max:bestScore`), største halvering (`max:biggestHalving`)
- Killer: kills (`kills`), K/D (`kills/max(attacksReceived,1)`)

### HEAD-TO-HEAD + nemesis
`headToHead` (uendret topp-4). Nemesis = motstanderen med flest tap-overskudd
(`losses - wins` størst, og `losses > wins`); merk raden med et lite «· nemesis».

## To kjente data-feil avdekket (avgjør i planfasen)

1. **ATC `max:bestDartCount` er feil retning.** Den bruker `setMax` → lagrer *flest* piler
   (tregeste finish), så «raskeste finish» kan ikke vises. Mockupen bruker derfor **treff-rate**
   i stedet. *Valg:* (a) la det ligge og vis treff-rate (anbefalt, null risiko), eller (b) fiks
   telleren til en min-variant (`max:` → ny `min:`-mekanisme i `ModeStats`/`StatsRecorder`) så
   «raskeste finish» blir mulig — egen liten endring.
2. **Killer mangler flest-kills-i-én-kamp.** Bare kumulativ `kills` lagres. Mockupen viser derfor
   **kills totalt**. *Valg:* (a) behold career-total (anbefalt), eller (b) legg til `max:bestKills`
   i Killer-recorderen for en ekte PB.

Anbefaling: gå med (a) på begge denne runden (holder scope additivt og null-risiko); de to
teller-utvidelsene kan tas som egen liten oppgave senere hvis du vil ha de PB-ene.

## Konsistens (per brukerens forbehold)

- **Farger:** kun `DossedartTokens`-paletten — cyan=deg/aktiv, gull/sølv/bronse=plassering/tier,
  grønn/rød=opp/ned (ELO, W/L), magenta=seksjons-aksent, phosphor=dempet, purple/orange/yellow som
  modus-aksenter i rekord-tiles. Ingen hex-literaler i Flutter-koden — `DossedartTokens.<rolle>`.
- **Chrome:** samme `_SectionCard`/SectionLabel-idiom og PressStart2P/VT323-fonter som resten av
  stats-skjermen og KAMPDETALJER. Nye seksjoner gjenbruker eksisterende sub-widget-mønstre.
- **Felter:** kun verdier som faktisk lagres (tabellen over). Tomme tellere → utelat eller «—».

## Tester

- Form-utledning: en kjent historikk → forventet W/L/U-sekvens + ΔELO per pip.
- PB-plukk: en spiller med kjente `max:`-tellere → forventede rekord-tiles; tom modus utelatt.
- Streaks/topp: kjente streak-felt + ratingHistory → forventet nå/beste/topp/rank.
- Nemesis: H2H med kjent tap-overskudd → riktig motstander merket.
- Widget: PROFIL rendrer alle seksjoner uten overflow på tablet-bredde; tom spiller (0 kamper)
  skjuler form/rekorder/per-modus pent.

## Avgrensning (ikke i denne runden)

- Ingen endring i MODUS/HEATMAP/HISTORIKK-fanene.
- Ingen nye tellere (med mindre du velger (b) på ATC/Killer over).
- Ingen 4-fane-restrukturering (egen, parkert sak).
