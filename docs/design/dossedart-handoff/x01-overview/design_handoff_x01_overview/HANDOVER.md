# HANDOVER — X01 overview (mode round 1/5) · 2026-07-22

**From:** Claude design (DOSSEDART track)
**Responds to:** `HANDOVER-to-design-2026-07-22-x01-overview-brief.md` + grammar sheet 2026-07-22
**Artboard:** `DOSSEDART x01 overview round.html` (canvas: today's card, 3 proposals, stress states, full cockpit, fasit)

## Decision

**Proposal B — standings rail on the right** (user-picked over A footer-strip / C standalone strip).
X01 is the template mode: this card is the reference skeleton the other four rounds restyle against.

## Fasit

```
OVERVIEW ZONE: h=272 px @ 820×1180 — all states fit, no growth
```

- Card **250px fixed** + margins 14/12/14/10. Never grows: every element always rendered, dimmed (opacity 0.34) when empty.
- Frame (grammar rule 5): `surface #1A0030` fill (today's gradient dropped) · 3px border in **player accent** · 14px accent glow · padding 14/12/14/12. **NOW THROWING badge dropped** — accent + name carry it.
- Header (rule 4): 56px photo avatar (silhouette fallback) · name curve 18/15/12/10 · three 9px dart pips + `DART n/3`.
- Primary (rule 6): REMAINING 60px Press Start 2P in player accent w/ glow — the only primary number.
- Left column, oche-legible (~1m): label PS-9 + value VT-26 rows — LAST (yellow, incl. sum) · AVG (white) + **HIT% (cyan, same row, 22px after AVG)** · CHECKOUT (green PS-14 w/ glow when ≤170, `— — —` dimmed otherwise; always rendered — this kills the 232→272 jump).
- Standings rail (rule 7): 300px right column, ALL players sorted ascending remaining — **incl. the active player** (3px accent border + accent bg so they see their own rank). Row = rank + accent dot + name + remaining VT-18. 👑 on unique leader. Bottom row: **TO WIN ▲n** delta vs leader (`YOU LEAD` / `TIED` when applicable). First dart of game (all tied 501): no crown, no delta.
- Long names: name curve bottoms at 10px above 16 chars; longer (tested: "Alexander the boss bitch", 24 chars) — header shows as much as possible, rail **middle-truncates to 16 chars** ("ALEXANDER…BITCH", start + end kept).

## PROPOSAL (needs sign-off, standard protocol)

- **HIT%** next to AVG — new data not in the brief (user ask). Suggested definition: hits on intended segment this leg; implementation owns the metric definition. Dimmed placeholder `—` on first dart.

## Implementation owns

Checkout computation · to-win math · HIT% definition + computation · all behaviour ·
`DossedartX01ActiveCard` rewrite · fixed-height regression test pinning 272px.

## Constraints honored

820×1180 · TopBar/board/glow/ActionBar untouched (approved chrome) · tokens only ·
Press Start 2P / VT323 · no border-radius · English UI strings.
