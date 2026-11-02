# Handoff: DuitKita Mobile App Redesign

## Overview
This package contains a complete UI/UX redesign of the **DuitKita** Flutter app — a Malaysian personal-finance + group-expense tracker. The redesign moves away from the existing purple gradient theme toward a calmer, dense **fintech aesthetic** (deep navy + mint, inspired by Wise / Revolut), and adds a structured **first-time user experience** (onboarding carousel, empty states, first-time tooltips, and a persistent Help button) so new users immediately understand what the app does.

The redesign focuses on these high-impact screens:
- **Onboarding** (first-launch carousel, 4 slides)
- **Home / Dashboard** (de-cluttered, one hero card + clear "Up next")
- **Groups list** + **Group detail** (members / activity / expenses tabs)
- **Add Expense** modal (3-step flow)
- **Debts & Bills** consolidated list
- **Profile** (with "How DuitKita works" entry point)
- **Help / tour overlay**
- **Empty states** (every list)

## About the Design Files
The files in this bundle are **design references created in HTML/React** — high-fidelity prototypes showing the intended look, layout, copy, and interactions. **They are NOT production code to copy directly.**

Your task is to **recreate these designs inside the existing DuitKita Flutter codebase**, using its existing patterns (Bloc, GoRouter, repositories, the established widget structure under `lib/features/...`). Treat the HTML as a visual + interaction spec; translate it into Flutter widgets, theme data, and routes.

If you're starting from scratch (no Flutter context), the recommended stack stays the same: **Flutter + Bloc + GoRouter**, with `flutter_animate` for transitions and `google_fonts` (Manrope) for typography.

## Fidelity
**High-fidelity (hifi).** Final colors, typography scale, spacing, radii, shadows, copy, and interaction patterns are all decided. Recreate pixel-perfectly. The only freedom you have is mapping HTML primitives to their Flutter equivalents (e.g., `Container` instead of `<div>`, `ListView` instead of overflow scroll).

## Design System

### Color Palette (Light Mode)
| Token | Hex | Usage |
|---|---|---|
| `bg` | `#F6F4EF` | App background (warm off-white) |
| `surface` | `#FFFFFF` | Cards, sheets |
| `surfaceAlt` | `#EFEDE6` | Subtle fills, progress tracks |
| `text` | `#0B1F3A` | Primary text (deep navy) |
| `textSecondary` | `#4B5C75` | Body text |
| `textTertiary` | `#8A99AE` | Captions, labels |
| `border` | `#E8E4DA` | Subtle dividers |
| `borderStrong` | `#CBC8BD` | Emphasised dividers, drag handles |
| `accent` | `#1ECDB0` | Primary mint accent (CTAs, progress) |
| `accentDeep` | `#0B7B66` | Accent text on soft accent fills |
| `accentSoft` | `#D4F5EC` | Soft accent backgrounds |
| `headerGradient` | `linear-gradient(135deg, #0B1F3A 0%, #14304F 100%)` | Hero balance card |
| `success` | `#1F8A5B` | Paid status |
| `successSoft` | `#DCF1E6` | Paid badge bg |
| `warning` | `#C97A0A` | Pending |
| `warningSoft` | `#FBEBD2` | Pending bg |
| `danger` | `#C9382A` | Unpaid, errors |
| `dangerSoft` | `#FBE1DD` | Danger bg |
| `info` | `#2A6FDB` | Info tooltips |
| `infoSoft` | `#DDE8F8` | Info bg |
| **Categories** | | |
| `catGroups` / `catGroupsSoft` | `#5B5BD6` / `#E4E4F8` | Groups (indigo) |
| `catDebts` / `catDebtsSoft` | `#C97A0A` / `#FBEBD2` | Loans (amber) |
| `catBills` / `catBillsSoft` | `#8B5CC9` / `#EBE0F7` | Bills (plum) |

### Color Palette (Dark Mode)
| Token | Hex |
|---|---|
| `bg` | `#070C18` |
| `surface` | `#0F1626` |
| `surfaceAlt` | `#1A2236` |
| `text` | `#F1F5FB` |
| `textSecondary` | `#A6B4CC` |
| `textTertiary` | `#6E7E96` |
| `border` | `#1E2840` |
| `borderStrong` | `#2C3753` |
| `accent` | `#1ECDB0` (same) |
| `accentSoft` | `#0F3D34` |
| `accentDeep` | `#7BE5CE` |

### Typography
- **Family:** `Manrope` (Google Fonts), weights 400/500/600/700/800
- **Display (balance):** 36px / 800 / -1.2 letter-spacing
- **H1 (large screen header):** 26px / 800 / -0.5
- **H2 (sheet titles, group name):** 22px / 800 / -0.4
- **Section header:** 16-18px / 800 / -0.3
- **Body:** 14px / 500-700
- **Caption:** 12-13px / 500-600
- **Label (uppercase):** 11-12px / 700 / 0.4 letter-spacing / uppercase

### Spacing Scale
4 / 8 / 10 / 12 / 14 / 16 / 18 / 20 / 24 / 28 / 32

Card padding: **14-18px**. Screen horizontal padding: **20px**. Section gap: **24px** (comfortable) / **18px** (compact).

### Radii
- Small (chips, status pills): `999px` (full)
- Inputs, small icon tiles: `10-12px`
- Cards: `16px`
- Hero cards, sheets: `22-24px`
- Bottom sheet top corners: `24px 24px 0 0`

### Shadows
- Card (light): none — rely on borders
- Bottom sheet / FAB: `0 6px 16px <text>40` (40 = ~25% alpha)
- Hero accent on dark: subtle radial mint glow

### Iconography
Custom 24×24 line icons drawn inline as SVG in `components.jsx`. Stroke-width 1.7 (default), 2.2 (active state), 2.4-3 (filled chevrons/checks). Use any equivalent line icon set in Flutter (e.g. `lucide_icons` or `phosphor_flutter`) — keep stroke weights consistent.

---

## Screens

### 1. Onboarding (`screens/onboarding.jsx`)
**Purpose:** First-launch only. Teaches new users what the app does.

- **Layout:** Full-screen, 4 horizontal slides, swipeable / pager.
- **Each slide:** Top illustration zone (~280px tall, custom SVG), title (28px / 800), body (15px / 500 / textSecondary), feature bullets (3 per slide).
- **Footer:** Page-dot indicator (active = mint pill, inactive = grey dot) + primary "Continue" / "Get started" button + "Skip" text button on slides 1-3.
- **Slides:**
  1. **"Money, sorted."** — overview, mint hero
  2. **"Split with your people."** — Groups feature
  3. **"Never miss a bill."** — Loans + Bills
  4. **"You're all set."** — final CTA "Get started"
- **Behaviour:** "Skip" or final "Get started" → calls `onDone()` which sets `showOnboarding=false` and persists. Re-launchable from Profile → "How DuitKita works" → "Show intro".

### 2. Home / Dashboard (`Home` in `screens/main.jsx`)
**Purpose:** Single landing surface — answers "what do I owe this month, and what needs my attention?"

**Layout (top to bottom):**
1. **Greeting header (12px top padding)** — Avatar (42px) + "Selamat petang," + first name + Help button (40×40 surface card with `?` icon) + Notifications bell (40×40, with red dot if unread).
2. **Hero balance card (20px margin, 22px radius, navy gradient `headerGradient`)** — 20px padding.
   - Label: "MONTHLY COMMITMENTS · MAY" (12px / 700 / uppercase / opacity 0.7)
   - Total: e.g. `RM 2,233.80` (36px / 800 / -1.2)
   - Status pill (top-right): "On track" with up-arrow icon (mint accent)
   - Progress section: "Paid RM 1,419 / RM 814 left" (12px) over a 6px-tall mint progress bar
   - Footer caption: "64% of monthly commitments cleared"
   - Decorative radial mint glow top-right
3. **First-time tooltip** (only on `firstTimeTip === 'home-hero'`): dark navy bubble below hero, "This card shows everything you owe…" + "Got it" dismiss.
4. **Quick actions row (4 columns)** — each is a 16px-radius surface card, 36px icon tile + 11px label:
   - **Add expense** (mint, plus icon)
   - **Pay QR** (amber, qr icon)
   - **New group** (indigo, users icon)
   - **Insights** (plum, pie icon)
5. **"Up next" section** (24px gap above) — list of `UpNextItem` cards. Each: 40×40 colored icon tile, title (14/700) + subtitle (12/secondary), amount (14/800) + small CTA pill ("Pay" filled, "Review" outline).
   - 3 sample items: Astro bill, Hakim Family group, Toyota Vios loan.
6. **"Where your money goes" breakdown card** — 3 rows divided by 1px borders:
   - Groups · 3 active · `RM 580`
   - Loans · 2 active · `RM 1,600`
   - Bills · 3 subscriptions · `RM 254`
   - Each row: icon tile, label, sub-label, total, chevron-right.

### 3. Groups List (`GroupsList`)
- **Header (large variant):** "Groups" (26/800) + subtitle "3 active · RM 580/mo" + plus button (40×40).
- **Filter chips (horizontal scroll):** All / Active / Pending / Settled. Active = filled navy.
- **Group cards** (column, 10px gap):
  - 44×44 emoji tile (colored bg by category)
  - Name (15/800) + chevron-right
  - Description (12/secondary)
  - **If monthly group:** "X/Y paid this month" + amount/mo + 4px progress bar
  - **If one-off:** "One-off split" pill + member count

### 4. Group Detail (`GroupDetail`)
- **Header bar:** Back button (40×40), spacer, share + settings buttons.
- **Group hero row:** 54×54 emoji tile + name (22/800) + description.
- **Stats card:** 3-column grid (Per member / Members / This month) with vertical dividers; below it a "Collection progress" 5px bar.
- **Action row:** 2-column — primary mint "Pay my share" (with QR icon) + secondary "Add expense".
- **Tab bar:** Members / Activity / Expenses (underline active). 13/700 labels.
- **Members tab:** List of cards — 40px avatar + name + role + status badge (Paid green / Pending amber / Unpaid red).
- **Activity tab:** Timeline cards — 36×36 status-colored icon + "Who [bold] action" + relative timestamp.
- **Expenses tab:** Empty state with "Add expense" CTA.

### 5. Add Expense Modal (`AddExpense`)
Bottom sheet, 92% max height, slides up (`cubic-bezier(.22,1,.36,1)` 0.3s).
- Drag handle (36×4 borderStrong)
- Header: dynamic title + close button
- 3-segment progress (4px bars, mint when active)
- **Step 1 — Type:** 2×2 grid of selectable cards (Group expense / Bill / Loan payment / Personal). Selected = mint border + soft mint bg.
- **Step 2 — Details:** Large amount input (32/800), title field, group picker (if type=group, list of selectable group cards with check), receipt drop zone (dashed border).
- **Step 3 — Review:** Summary card (36px amount), key-value review rows, info banner ("Group admins will receive a notification…").
- **Footer:** sticky on `surface` with top border. "Back" (secondary) + "Continue" / "Confirm & submit" (primary, full width).

### 6. Debts & Bills (`DebtsScreen`)
- Two sections: "Loans" + "Bills & subscriptions".
- **Loan card:** Icon tile + title + sub + monthly amount + remaining; 4px progress bar (success green if paid this month, amber otherwise); footer with "Paid this month" / "20% repaid total".
- **Bill card:** Icon tile + title + sub + amount + 28×28 checkbox (filled green check if paid).

### 7. Profile (`ProfileScreen`)
- User identity card (avatar + name + email + chevron).
- Settings list card with 4 rows divided by borders:
  - **How DuitKita works** → opens Help overlay
  - Security & privacy
  - Notifications
  - About v2.0

### 8. Help Overlay (`HelpOverlay`)
Bottom sheet, 90% max height. 3 explanatory cards (Groups / Loans / Bills), each with an icon + 4 numbered steps. Footer 2-button row: "Replay tips" (resets first-time tooltips) + "Show intro" (re-runs onboarding).

### 9. Empty States (`EmptyState`)
Used wherever a list is empty. Pattern:
- 88×88 surface tile with line icon, mint "+" badge in top-right corner
- Title (22/800) + body (14/secondary, max 280px width, centered)
- Primary mint CTA button
- Optional "How it works" panel — 3 numbered steps in a surface card

### 10. Bottom Nav (`BottomNav`)
- 5 slots: Home / Groups / **+ FAB** / Debts / (JDT or Profile, depending on `showJdt` tweak).
- Active = navy text + bolder weight; inactive = textTertiary.
- Centre FAB: 52×52, navy fill, 18px radius, raised 16px above row, navy shadow.
- Hidden on Group Detail and when Add Expense modal is open.

---

## Interactions & Behaviour

| Interaction | Trigger | Result |
|---|---|---|
| First launch | App start, `showOnboarding === true` | Show Onboarding pager |
| Onboarding "Get started" | Final slide CTA | Persist `showOnboarding=false`, navigate to Home |
| Tap Help (?) | Header on Home, or Profile row | Open Help overlay (slide up) |
| Help "Show intro" | Inside Help overlay | Re-show Onboarding |
| Help "Replay tips" | Inside Help overlay | Reset first-time tooltips |
| Tap "Got it" on tooltip | Home hero tooltip | Dismiss (session-only) |
| Tap "+" centre nav | Bottom nav | Open Add Expense bottom sheet |
| Tap group card | Groups list | Push Group Detail |
| Tap "Pay my share" | Group Detail | (stub) Would open QR pay sheet |
| Add Expense Continue | Step button | Advance step (1→2→3) |
| Add Expense Confirm | Step 3 | Close modal |
| Tap any tab on Group Detail | Tab bar | Swap inner content |
| Pull-to-refresh | Any list | (not implemented — wire to repository) |

### Animations
- Bottom sheets: `transform: translateY(100% → 0)` over 300ms `cubic-bezier(.22,1,.36,1)`.
- Tooltip appear: `fadeIn` 400ms (opacity + 4px translateY).
- Progress bars: `width` transitions over 300ms.
- Tab underline: instant (no animation in mock — feel free to add a 200ms slide).

---

## State Management
Suggested Bloc structure (matches existing DuitKita patterns):

| Cubit / Bloc | State |
|---|---|
| `OnboardingCubit` | `seen: bool` (persisted in `SharedPreferences`) |
| `HomeCubit` | `monthlyTotal`, `paidThisMonth`, `upcomingItems[]`, `breakdown` |
| `GroupsCubit` | `groups[]`, `filter: All/Active/Pending/Settled` |
| `GroupDetailCubit` | `group`, `members[]`, `activity[]`, `expenses[]`, `tab` |
| `AddExpenseCubit` | `step`, `type`, `amount`, `title`, `selectedGroupId`, `attachments` |
| `TipsCubit` | `dismissedTipIds: Set<String>` (persisted) |
| `ThemeCubit` | `mode: light/dark`, `density: comfy/compact` |

---

## Files in this bundle
- `DuitKita Redesign.html` — entry point, mounts the React app inside an Android-shaped device frame
- `app.jsx` — root component, routing, tweaks integration
- `components.jsx` — primitives (`Icon`, `Card`, `Button`, `Avatar`, `Pill`, `Tooltip`, `StatusBar`, `NavBar`, `SectionHeader`, `fmt`)
- `theme.jsx` — `useTheme(mode, density)` returning color + density tokens
- `screens/onboarding.jsx` — onboarding carousel
- `screens/main.jsx` — Home, Groups, Group Detail, Add Expense, Help, Empty State, Bottom Nav
- `tweaks-panel.jsx` — runtime tweak controls (light/dark, density, JDT toggle)

To preview: open `DuitKita Redesign.html` in any browser (or via `python -m http.server` from the bundle root if file:// CORS blocks it).
