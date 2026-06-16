# KAMPDETALJER — statistikk-drilldown (alle moduser)

**Dato:** 2026-06-16
**Status:** Godkjent design — klar for implementeringsplan
**Kilde:** Handover `DOSSEDART (4).zip` → `design_handoff_stats_board_round/` (PART 2). Board-delen (PART 1, CRT-farger) er allerede landet separat.

## Mål

I dag er `HISTORIKK`-fanen en blindvei: en liste (modus · dato · vinner · ΔELO) uten å kunne gå inn i en kamp. Denne featuren gjør hver kamprad **klikkbar** og leder til en ny **KAMPDETALJER**-skjerm med sluttstilling + ΔELO, prestasjonene hver spiller oppnådde, hele spillforløpet (progresjon mot mål + runde-for-runde-logg) og en side-om-side per-spiller-sammenligning.

**Scope (besluttet under brainstorming):**
- Full skjerm inkl. spillforløp-graf + runde-logg (krever modellendring: lagre throwHistory per kamp).
- **Alle 6 moduser** (X01, Cricket, Killer, Shanghai, ATC, Splitscore) — full skjerm, ikke bare X01.

## Bakgrunn — hva finnes i koden i dag

Verifisert mot kodebasen:

| Ting | Status i dag |
|------|--------------|
| `GameHistoryEntry` (`lib/models/game_history.dart`) | har `id, gameMode, date, players[]` |
| `GameHistoryPlayer` | har `name, savedPlayerId, placement, stats: Map<String,int>, ratingBefore/After, ratingDelta` |
| Per-spiller-tellere i historikk | = `modeCounters` (X01: totalTurnScore/totalTurns/totalDarts/highestTurn/doublesHit/triplesHit/bullsHit/turnsOver100/bestCheckout/segmentHits) |
| 180/140-antall, checkout-kombo (streng), ekte dobbel-rate | **lagres ikke** i historikk i dag |
| `throwHistory: List<DartThrow>` | finnes i minnet i **alle 6** game-skjermer (samme `DartThrow`-form), men **persisteres ikke** |
| `DartThrow` (`lib/models/dart_throw.dart`) | har `playerIndex, segment, multiplier, points, scoreBefore, turnNumber, scoreAtStartOfTurn, turnId, roundNumber, isBust` + `label`/`shortLabel`. **Ingen JSON-serialisering.** |
| Achievements | unlocks lagres globalt på `SavedPlayer.unlockedAchievementIds` + tidsstempel — **ingen kobling til en spesifikk kamp** |
| Per-kamp feats | `X01Feats` (`x01_achievement_feats.dart`) + `cricketMaxMarksInTurn`; Killer/Shanghai/ATC/Splitscore beregnes inline/i engine ved kampslutt (`awardGameEnd()` kjører for alle moduser) |
| `_HistoryRow` (`dossedart_stats_screen.dart`) | ren `Container`, **ikke** klikkbar |
| Achievement tier-farger | `AchievementTier {bronze, silver, gold}` → `DossedartTokens.bronze/silver/yellow` (`achievement_medal.dart`) |

## Valgt tilnærming: A — fang per-kamp-data ved kampslutt

Lagre `throwHistory` + en per-spiller `earnedFeats`-liste på `GameHistoryEntry` når kampen avsluttes. Spillskjermene regner allerede ut feats for achievement-systemet — vi gjenbruker den beregningen. Fungerer for alle moduser, også engine-avledede feats (instant-Shanghai), og gir én sannhetskilde per kamp.

Forkastet: (B) lagre kun throwHistory og regne ut alt ved visning — kan ikke gjenskape engine-only feats eller en ren per-kamp unlock-diff. (C) kompakt per-runde-oppsummering — modus-spesifikk serialisering og mister per-pil-detalj; rå `DartThrow` er allerede uniform.

## Design

### 1. Datamodell (`lib/models/`)

**`DartThrow`** — legg til `toJson()`/`fromJson()`. Alle felt serialiseres.

**`EarnedFeat`** (ny, liten modell):
```
class EarnedFeat {
  final String label;        // "180!", "9 MARKS", "INSTANT SHANGHAI"
  final AchievementTier tier; // bronze/silver/gold (gjenbruk eksisterende enum)
  final String? note;         // "Maks i runde 1", "T20·T20·T20"
  final FeatKind kind;        // unlock (★ ny achievement) | feat (✦ in-game-bragd)
  final int? round;           // hvilken runde (for attribusjon)
}
enum FeatKind { unlock, feat }
```

**`GameHistoryEntry`** — nye, nullbare felt:
- `throwHistory: List<DartThrow>?` — null ⇒ tomtilstand for graf/logg.
- `gameConfig: String?` — banner-tekst, f.eks. «501 · Dobbel ut», «Cricket», «Killer · 3 liv».
- `durationSeconds: int?` — kampvarighet (banner). Runder utledes av maks `roundNumber`.

**`GameHistoryPlayer`** — nytt, nullbart felt:
- `earnedFeats: List<EarnedFeat>?`

Alle nye felt nullbare → eksisterende lagrede kamper deserialiseres uendret og faller til tomtilstand.

### 2. Fangst ved kampslutt

Utvid `StatsRecorder.recordGame(...)` med valgfrie parametre `throwHistory` + per-spiller `earnedFeats` + `gameConfig` + `durationSeconds`. De 6 game-skjermene sender inn det de allerede beregner ved `awardGameEnd()`. `StatsRecorder` skriver feltene på `GameHistoryEntry`/`GameHistoryPlayer`.

### 3. Modus-progresjon (spillforløp-graf)

`ModeProgression`-strategi: gitt `throwHistory` + spiller → tallserie per runde + akse-config (maks, retning «mot 0» vs «klatre», mållinje).

| Modus | Serie | Retning |
|-------|-------|---------|
| X01 | restscore etter hver tur (`scoreAtStartOfTurn`/avledet) | mot 0, ✓ UT-flagg |
| Cricket | kumulative poeng (evt. marks) per runde | klatre |
| Killer | liv over turer | mot 0 (eliminasjon) |
| ATC | nådd tall-indeks per runde | klatre mot 20 |
| Shanghai | kumulativ score per runde | klatre |
| Splitscore | løpende totalscore per runde | klatre (kan halveres ↓) |

### 4. Per-spiller-grid

Utledes **rikt** fra `throwHistory` når den finnes (snitt, beste runde, 180/140, checkout-kombo, dobbel%, piler). Faller tilbake til lagrede `stats`-tellere for gamle kamper; rader uten datagrunnlag viser «—». Per-mode utledning (X01 vist i handover; andre moduser bruker sine naturlige tellere).

### 5. UI

- Ny skjerm `GameDetailScreen(GameHistoryEntry entry)`.
- Gjør `_HistoryRow` klikkbar (`onTap → GameDetailScreen`); restyle raden til topp-3 mini-stilling + din ΔELO + «DETALJER ›».
- Seksjoner (topp→bunn) per handover: header (◀ HISTORIKK · KAMPDETALJER · DEL ↗) → match-banner → SLUTTSTILLING → PRESTASJONER DENNE KAMPEN (2-kol feat-chips, hexagon tonet av tier, ★ unlock / ✦ feat, attribuert til spiller) → SPILLFORLØP (graf + runde-logg med pil-chips: trippel=cyan, dobbel=magenta, single=dim; 180 uthevet gult; «VIS ALLE N RUNDER ›») → PER SPILLER (side-om-side, bedre verdi uthevet grønn).
- Gjenbruk DOSSEDART-chrome, `achievement_medal`/tier-farger, `DossedartTokens`.
- Modus-agnostisk skall: samme skall for alle moduser; seksjonene fylles av modus-spesifikke counters/progresjon.
- Fargesemantikk: cyan=deg, gull/sølv/bronse=plassering, grønn/rød=ELO opp/ned, trippel=cyan/dobbel=magenta på pil-chips (matcher brettet).
- `DEL ↗` gjenbruker eksisterende share-mekanisme (`share_plus`).

### 6. Tomtilstand

Kamper lagret før `throwHistory` fantes: vis sluttstilling + ΔELO + per-spiller-tellere + (evt.) prestasjoner; skjul graf/logg med linjen «forløp ikke lagret for denne kampen».

### 7. Retensjon

`throwHistory` legger ~50–80 `DartThrow` per kamp i SharedPreferences-JSON. For å unngå at lagringen vokser ubegrenset: behold `throwHistory` kun for de **100 siste** kampene; eldre kamper får `throwHistory = null` (faller til tomtilstand). Sluttstilling/ΔELO/per-spiller/feats beholdes for alle kamper. Grensen er en konstant og enkel å justere.

## Tester

- JSON round-trip: `DartThrow`, `EarnedFeat`, `GameHistoryEntry` med og uten nye felt (bakoverkompatibilitet med gamle lagrede kamper).
- Per-modus `ModeProgression` fra en kjent `throwHistory` → forventet serie.
- Feats-fangst: en kamp produserer forventede `earnedFeats` per spiller.
- Retensjon: kamp #101 trimmer eldste throwHistory.
- Widget: tomtilstand skjuler graf/logg og viser fallback-linje.

## Konsistens

- Endringen i `_HistoryRow` + ny skjerm må følge samme arcade-chrome, AppBar/bottom-bar-mønster og fargepalett som resten av DOSSEDART (jf. konsistens-på-tvers-av-moduser).
- KAMPDETALJER er additiv (ny skjerm nådd fra historikk) og uavhengig av den parkerte 4-tab stats-restruktureringen — bør ikke kollidere.

## Avgrensning (ikke i denne runden)

- Ingen redesign av selve HISTORIKK-fanen utover å gjøre rader klikkbare + mini-stilling.
- Ingen endring i hvordan achievements låses opp/lagres globalt — vi fanger kun en per-kamp `earnedFeats`-kopi for visning.
