# DOSSEDART X01 — handover til Claude Design

**Dato:** 2026-05-22
**Fra:** Claude Code (implementasjons-sesjon)
**Hva:** Vi har rotet oss inn i et fargeproblem på X01 spillebrett. Trenger et friskt designblikk.

## Kontekst — hva DOSSEDART er

Hobbyprosjekt: Flutter-app for dart-scoring (X01, Cricket, ATC, Killer, Splitscore, Shanghai). Kjører på en Samsung Galaxy Tab i hjemmet — det er den eneste enheten det skal funke godt på.

DOSSEDART er et arcade/CRT-tema for appen. Paletten er låst:

```
--bg:       #0a0014   (dyp blå-svart, screen-bg)
--surface:  #1a0030   (mørk lilla, panel-bg)
--magenta:  #FF00AA
--cyan:     #00E5FF
--yellow:   #FFD200
--orange:   #FF7A00
--red:      #FF3050
--green:    #3DFF8E
```

Typografi: `Press Start 2P` (pixel-font) for tall/labels, `VT323` (terminal-font) for sekundærtekst.

CRT-effekter er allerede implementert: scanlines (30 % svart hver 4 px) + radial vignette (mørkner kanter). De gjelder hele appen via `ArcadeFrame`.

## Handovers så langt

Eksisterende handover-mockups i `docs/design/dossedart-handoff/`:

- `DOSSEDART home arcade overhaul.html` — home-skjerm (implementert, fungerer fint)
- `DOSSEDART x01 ingame.html` — første X01 cockpit-skisse
- `PROPOSAL-cockpit-v2.html` til `PROPOSAL-cockpit-v5.html` — utviklet cockpit-design fram til v5
- `PROPOSAL-player-overview-v2.html` til `PROPOSAL-player-overview-v4.html` — player-overview-screen

PR #8 implementerte v5 av cockpit + Player Overview. Det er live i v1.8.0.

## Hva som FUNGERER bra

- Home-skjermen (DOSSEDART arcade) — bruker fikk Bjørn til å si "fungerer fint" gjentatte ganger.
- X01 active-card (øvre del av cockpit) — etter en fix i denne sesjonen, leselig og fin.
- Top-bar og bottom-action-bar (UNDO / MISS / MENU) — fine.
- CRT-scanlines + vignette globalt — OK.
- Setup-skjermer for alle modi.

## Hva som IKKE fungerer — dette er handover-punktet

### Problem: X01 dartboard-fargene

Etter at vi fjernet en feilaktig "CRT glass-bulge"-skygge i denne sesjonen (som la en mørk sky over midten av cockpit), kan Bjørn endelig SE dartboardet. Da var reaksjonen: **"fargene er helt jævlige, altså helt forferdelige"**.

Vi spurte hva som er stygt. Han plukket disse tre:

1. **Triple-ringen (grønn) og double-ringen (gul) skriker for høyt** — de er solid neon-grønn og solid neon-gul, ved siden av hverandre, og tar all oppmerksomhet.
2. **Hele paletten er feil — rainbow-effekt fungerer ikke** — magenta + cyan + grønn + gul + orange + rød alt sammen = sirkus.
3. **Brett-bg (mørk lilla) gjør at ingen farger står ut** — surface-fargen under brettet er for dempet sammenlignet med home (som har svart bg under fargete elementer).

Han plukket IKKE "single-bandene (magenta/cyan) er for transparente" — han er enten OK med alpha 0.35 eller har ikke lagt merke til det.

### Nåværende dartboard

`lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart`:

- 20 segmenter, alternerende
- Inner+outer single bands: magenta / cyan alternerende, `alpha 0.35` (gjennomsiktig)
- Triple ring: solid grønn (`#3DFF8E`)
- Double ring: solid gul (`#FFD200`)
- Bull (sentrum-1): solid orange (`#FF7A00`)
- D-Bull (sentrum): solid rød (`#FF3050`)
- Bg under brettet: `#1a0030` (mørk lilla surface)
- Ytre magenta-sirkel (3 px stroke) som grenser
- Numbers (1-20) i hvit Press Start 2P

### Mine egne 3 forslag — som Bjørn syns drar for langt vekk

Lagret i `docs/design/dossedart-handoff/PROPOSAL-dartboard-colors-v1.html` for referanse:

- **A — Tradisjonell dart-look:** cream + mørk singles, rød+grønn triple+double. Klassisk dart-stil. Mistet arcade-følelsen.
- **B — Mono DOSSEDART:** mørk/lys-lilla singles, magenta triple, cyan double. Kun to neon-farger. (Bjørn lener mot denne, men er ikke overbevist.)
- **C — Solid neon med dempet triple/double:** beholder magenta/cyan singles solide, demper triple til oliven og double til messing.

Alle tre byttet bg til svart for kontrast.

## Hva vi tror Bjørn vil ha

- **Færre konkurrerende farger.** "Rainbow" er ute.
- **Triple/double må roes ned**, men må fortsatt være identifiserbare (de er sentrale i scoring).
- **Bg under brettet må gi kontrast** — solid svart eller mørk navy, ikke mørk lilla.
- Bullseye-konvensjon (bull i en farge, d-bull i en annen) bør beholdes — det er gjenkjennbart.
- DOSSEDART-paletten skal fortsatt være "stedsfølelsen" — det er en arcade-app, ikke en realistisk dart-simulator. Men ikke skrik.
- **Konsistens med resten av cockpit:** topbar/active-card/action-bar bruker magenta border + cyan accents + yellow titler. Brettet må ikke se ut som det er fra en annen app.

## Hva vi IKKE har prøvd

- Helt mørke singles (no color, bare svart/grå) med kun ett accent på triple/double
- Bare lysstyrke-variasjon på singles (mørk vs lys surface, ingen farget signal der)
- Outline-only triple/double (border, ikke fyll)
- Sektorfarger basert på score-verdi (høyere score = lysere farge)

## Tekniske constraints

- Brettet rendres som CustomPaint på en Canvas. Hvilken som helst farge-mix er teknisk mulig.
- Tap-håndtering er polar (radius + vinkel → segment), uavhengig av rendering.
- Numbers ligger på `r * 0.975` (litt utenfor double-ringen). Kontrast må fungere mot uansett valgt outer-bg.
- Brettet er en sirkel av størrelse `screenWidth - 28` ≈ 380 px på testenheten.
- Hele brettet skal kunne nås med tap; inn-til-D-bull og ut-til-corner er sensitive.

## Spør Claude Design om

1. En palett for brettet som adresserer Bjørn's tre punkter ovenfor.
2. Forslag på hva bg under brettet skal være (svart, dyp navy, samme som screen-bg, annet?).
3. Bør singles ha noen farge i det hele tatt, eller skal de bare være "tom plass" så triple/double står ut?
4. Hvis du har en helt annen tanke om hvordan en arcade-stil dartboard kan se ut — leverer du den helst som HTML-mockup i samme format som de eksisterende `PROPOSAL-*.html`-filene.

## Andre QA-funn i denne sesjonen (ikke til Claude Design — vi fikser i koden)

- Tap utenfor brett-sirkelen (men innenfor brett-firkanten) registrerer ikke miss lenger. Skyldes at vi fjernet en Container med decoration; løses med `HitTestBehavior.opaque` på GestureDetector.
- "Siste 3 piler" vises ikke på active-card — vi tror dette er at logikken fungerer (vises kun etter fullført tur), men må verifiseres.
- MISS-knapp skal ha bittelitt mer glow.

Disse trenger ikke design-input — bare kode-fix.

## Filer Claude Design kan se på

- `docs/design/dossedart-handoff/PROPOSAL-cockpit-v5.html` — siste cockpit-design (det dartboardet sitter inni)
- `docs/design/dossedart-handoff/DOSSEDART home arcade overhaul.html` — for å se home-stilen som fungerer
- `docs/design/dossedart-handoff/PROPOSAL-dartboard-colors-v1.html` — mine 3 avviste forslag (kan brukes som "ikke dette"-referanse)
- `lib/widgets/dossedart/x01/dossedart_x01_dartboard.dart` — nåværende implementasjon

Takk!
