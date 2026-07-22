# Cockpit grammar sheet (2026-07-22)

**To:** Claude design (DOSSEDART track)
**From:** implementation
**Replaces:** `HANDOVER-to-design-2026-07-21-cockpit-overview-grammar.md` — that round asked for
everything at once and is withdrawn. New process: approve THIS one-page rule sheet first, then one
small round per mode (X01 → Killer → Gotcha → 1UP → Wildcard), each with its own one-pager.

**Scope:** the overview zone (between TopBar and dartboard) in the five dartboard-input cockpits:
X01, Killer, Gotcha, Wildcard, 1UP. Nothing else. This sheet has **no artboard deliverable** —
just confirm or push back on the rules below; the per-mode rounds do the drawing.

---

## The template is X01

The X01 active card is the reference: its frame, header, and size hierarchy become the shared
grammar. Every other mode's overview is a restyle onto this skeleton with its own data. Two points
where X01 itself adopts from the newer cockpits instead (rules 3 and 6 below).

## The rules

1. **One fixed zone height: `272 px` @ the 820 × 1180 frame — identical in all five modes.**
   Measured from X01's max state today (card 250 px + margins 12/10). This is a ceiling, not a
   target. Every state of every mode fits inside it; whatever is left over is board zone, so the
   dartboard has the same size and position in all five cockpits and tap targets never move —
   between darts or between modes.
2. **Nothing grows or collapses at runtime.** Helpers/chips/status lines with no content dim or
   show a placeholder (Gotcha's helper-bar pattern, X01's `— · — · —` LAST row). This closes the
   overview-vs-board overlap bugs we have patched locally in three modes. Consequence for X01
   itself: the checkout strip becomes always-rendered (dimmed/placeholder when no checkout) —
   today it appears and disappears, which is where the 232→272 px jump comes from.
3. **Active accent = per-player accent** (from 1UP/Wildcard), replacing X01/Gotcha's locked cyan.
   Fixes the standing tester complaint that the active thrower is hard to spot. Chrome stays
   magenta. Mode-semantic states (1UP green-SAFE/red-danger, Wildcard purple-modifier) stay as
   deviations from this neutral rule.
4. **One header** (X01's): avatar 56 px + name (X01's length→size curve: 18/15/12/10) +
   three 9 px dart pips + `DART n/3`. One avatar treatment for all five modes — today we ship
   photo / initials / 3-letter handle / none; pick one (photo w/ silhouette fallback is what X01
   ships).
5. **One card frame** (X01's): `surface` fill, 3 px accent border, 14 px accent glow,
   margins 14/12/14/10, padding 14/12/14/12. No gradients, no per-mode margin sets.
6. **Size hierarchy: one primary number per card** — the mode's oche-legible value (X01's
   REMAINING at 60 px is the reference) — plus at most two secondary fields and one helper strip.
   If a mode wants more, it goes in the standings element or the player sheet.
7. **Standings are mandatory:** every mode shows all opponents at a glance inside the zone — one
   shared compact pattern (Wildcard's standings strip is the proven shape), fed mode-specific
   data. Per-mode flavour on top (climb-bar ticks, danger skulls) is fine.

## Division of labor

- **Design owns:** confirming/adjusting these rules, then per-mode artboards in the coming rounds.
- **Implementation owns:** all behaviour, component APIs/merging, and a fixed-height regression
  test per mode pinning the 272 px budget once the rounds land.

## Fixed constraints (unchanged from previous handoffs)

820 × 1180 portrait frame; CrtFrame/TopBar/ActionBar/board + glow reused verbatim; DOSSEDART
tokens only (incl. lime `#C6FF3C`); `Press Start 2P` / `VT323`; no border-radius; all UI strings
English; new functionality is PROPOSAL-only.
