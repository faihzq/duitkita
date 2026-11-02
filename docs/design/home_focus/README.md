# DuitKita — Home "Focus" Redesign · Developer Handoff

Realized design: **`Home Redesign B.html`** (open it side-by-side while implementing).

The Focus direction keeps every feature and section of today's Home — it restructures the top of the screen so the most useful number (**what's left to pay this month**) leads, and the things that need action (**Up next**) stand out.

## What actually changes

Only **three widgets** in `lib/features/home/home_screen.dart` change. Everything else — greeting header, notification bell + sheet, admin pending section, insights sheet, bottom nav — stays exactly as-is.

| # | Widget | Change |
|---|--------|--------|
| 1 | `_HeroCard` | Big number becomes **remaining** (not total). Linear bar → **circular ring** of % cleared. Label `MONTHLY COMMITMENTS` → `LEFT TO PAY`. Quick actions move **inside** the hero as translucent chips. |
| 2 | `_UpNextSection` / `_UpNextCard` | Header gains a **"3 to pay"** count pill. The **first** item is emphasized: warning border + "DUE SOON" chip + warning Pay button. |
| 3 | `_BreakdownCard` | A thin **segmented bar** (weighted by amount) sits above the existing rows. |

No data-layer, provider, or navigation changes. Same totals, same `onTabChange`, same taps.

## Files in this folder

- **`hero_ring.dart`** — new file. Drop into `lib/features/home/`. Provides `HeroRing` and `AnimatedHeroRing` (a `CustomPainter` ring — Flutter has no built-in). Uses `DT.accent` for the arc.
- **`home_focus_snippets.dart`** — annotated before/after edits for the three widgets, with the exact structures to paste. Reads as a guide, not a compilable file — the helper fns show the shape; wire them into your existing widget classes.

## Step-by-step

1. Add `hero_ring.dart` to `lib/features/home/` and import it in `home_screen.dart`.
2. **Hero** — in `_HeroCard.build`, replace the inner column (Paid/Remaining labels + `LinearProgressIndicator`) with the ring+amount `Row` from CHANGE 1. Change the label text. Move the `_QuickActions` block out of `HomeScreen.build`'s outer `Column` and pass a dark-chip version into the hero (CHANGE 1b).
3. **Up next** — add `bool soon` to `_UpNextItemData` (set `soon: items.isEmpty` on the first added item), pass `upNextCountPill(items.length)` as the `_SectionHeader` action, and branch the card's border / title chip / Pay button on `item.soon` (CHANGE 2).
4. **Breakdown** — insert `breakdownSegmentBar(...)` as the first child of the card's Column (CHANGE 3).
5. Run. The ring animates 0→% on first paint via `AnimatedHeroRing`.

## Tokens (unchanged — from `lib/config/design_tokens.dart`)

`DT.accent #00C2A8` (ring, "paid" text) · `DT.warning #F59E0B` + `DT.warningSoft #FEF3DC` (Up-next emphasis, count pill) · category colors for the segment bar (`catGroups`, `catDebts`, `catBills`). Hero gradient `headerGradientStart/End`. Type: Manrope throughout.

## Using with Claude Code

Point Claude Code at this folder and `home_screen.dart`:

> Apply the Home "Focus" redesign in `design_handoff_home_focus/` to `lib/features/home/home_screen.dart`. Add `hero_ring.dart` to `lib/features/home/`. Make only the three changes described in `home_focus_snippets.dart` (hero ring + in-hero chips, Up-next emphasis + count pill, breakdown segment bar). Keep all other sections, providers, and navigation unchanged.
