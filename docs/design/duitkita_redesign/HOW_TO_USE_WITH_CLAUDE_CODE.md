# How to apply this design in Claude Code (VS Code)

## What's in this bundle
- `README.md` — full design system + screen specs (the source of truth)
- `DuitKita Redesign.html` — open in a browser to see the live prototype
- `app.jsx`, `components.jsx`, `theme.jsx`, `tweaks-panel.jsx` — supporting React code
- `screens/` — one JSX file per screen:
  - `onboarding.jsx` — 4-slide first-launch carousel
  - `main.jsx` — Home, Groups list, Group detail, Add Expense bottom sheet, Help overlay, Empty states, Bottom nav, Debts/Bills, Profile
  - `new_expense.jsx` — full-screen New Expense form
  - `add_payment.jsx` — Add Payment with multi-month support
  - `expense_approval.jsx` — Admin expense review + approve/reject confirmation

These are **design references in React**, not code to copy. Your job in Claude Code is to translate them into Flutter widgets inside `lib/screens/...`.

---

## Step-by-step in VS Code

### 1. Drop the handoff into your repo
Unzip the bundle and put the `design_handoff_duitkita_redesign/` folder anywhere in your Flutter project. Suggested location:

```
duitkita/
├── lib/
├── android/
├── ios/
├── design_handoff_duitkita_redesign/   ← here
└── pubspec.yaml
```

### 2. Open the repo
```
code path/to/duitkita
```

### 3. Preview the design alongside Claude Code
Open `design_handoff_duitkita_redesign/DuitKita Redesign.html` in Chrome. Keep it visible while you work — use the Tweaks panel (top-right) to navigate between screens:
- Open New Expense screen
- Open Add Payment screen
- Open Expense Approval screen
- Replay onboarding

For Home, Groups, and Group Detail — use the bottom nav.

### 4. Start Claude Code with a focused prompt

Open Claude Code in VS Code. Don't ask it to do everything at once — go screen by screen. Use these prompts as templates:

#### Prompt 1 — Set up the theme

> Read `design_handoff_duitkita_redesign/README.md`.
> 
> Update `lib/config/app_theme.dart` to match the new "calm fintech" palette documented under **Design System → Color Palette (Light Mode)**. Replace the purple primary with deep navy `#0B1F3A`, add mint accent `#1ECDB0`, off-white background `#F2F4F7`, and the three category colors (indigo for groups, blue for loans, amber for bills). Also add `Manrope` as the app font via `google_fonts` package.
> 
> Keep the existing class structure (`AppTheme.primary`, `AppTheme.accent`, etc.) so I don't have to refactor every screen yet. Just swap the hex values and add the new tokens.

#### Prompt 2 — Redesign one screen at a time

Pick a screen, then say:

> Read `design_handoff_duitkita_redesign/screens/add_payment.jsx` and the **Add Payment** section of the README.
>
> Redesign `lib/screens/add_payment_screen.dart` to match this design EXACTLY. Specifications below — match every measurement.
>
> **Layout structure (top to bottom):**
> 1. **Navy gradient header** (`#0B1F3A → #14304F`, vertical), 14px top + 16px horizontal + **22px bottom** padding. Contains:
>    - 38×38 back button (radius 11, `rgba(255,255,255,0.12)` bg, 1px white-15% border) on the left
>    - Title "Add Payment" (16px / 800 / -0.2) + subtitle "Hakim Family · monthly contribution" (11px / 500 / 65% opacity)
>    - 16px gap below, then auto-approve pill: mint bg `rgba(30,205,176,0.18)`, 1px mint-30% border, sparkle icon + "Auto-approve enabled" (11px / 700)
> 2. **Bank account card — overlapping the header**. CRITICAL: this card sits ON TOP of the navy header by overlapping upward. Implementation:
>    - Margin: `-12px 16px 0` (negative top margin pulls it up into the navy)
>    - Background: white surface, radius **18px**, padding **18px 18px 16px**, large shadow `0 10px 30px rgba(11,31,58,0.08)`, 1px border
>    - Inside the card:
>      - Top row: 36×36 yellow tile (`#FFCC02`, radius 10) with navy `#003B6F` bank icon → "PAY TO" uppercase label (11/700/secondary) + "Maybank" (15/800/text) → Copy button (6×10 padding, surfaceAlt bg, switches to successSoft + check icon when copied)
>      - Account number block: monospaced, 20px / 800, letter-spacing 1, padded 12×14, surfaceAlt bg, radius 10
>      - Bottom row: "ACCOUNT HOLDER" label + holder name, with 36×36 mint-soft QR button on the right
> 3. **Scrollable form area** below, 16px padding, contains sections in order: Pay for X months / quick preset chips / selection breakdown (only when multi) / Amount / Payment date / Reference.
> 4. **Sticky footer** outside the scroll area: 12×16×14 padding, top border, soft shadow upward, contains summary row (selection · date · amount) + full-width mint accent CTA with checkCircle icon.
>
> **Multi-month support:**
> - Tapping a month toggles it in/out of `selectedMonths` array
> - Already-paid months are disabled (green success-soft bg + check icon)
> - Selected months get a small mint badge in the corner showing order (1, 2, 3...)
> - Quick presets: "This month / 3 months / 6 months / 12 months" — auto-selects N consecutive unpaid months starting from current
> - When >1 month selected: show a separate breakdown card with removable chips and a `N × RM 200` pill
> - Amount auto-calculates `months × monthlyDue`, shown with a "Auto-calculated 🔒" indicator; tap to unlock and edit manually
> - If user enters less than monthly due (single month) or amount doesn't match `months × due` (multi), show amber warning banner inline
>
> **Date selector:** 3 chips (Today / Yesterday / Pick date). Active = navy fill with check icon. "Pick date" expands a native date input row below.
>
> **Reference:** optional field, receipt icon prefix, plain text input.
>
> Keep the existing data layer (`paymentServiceProvider`, etc.). Only change the UI in the build method. **Show me your plan before writing code.**

Repeat for each screen you want migrated. Order I'd recommend:

1. **Theme tokens** (`app_theme.dart`) — foundation
2. **Home / Dashboard** (`home_screen.dart`)
3. **Add Payment** (`add_payment_screen.dart`)
4. **Add Expense** (`add_expense_screen.dart`) — uses `new_expense.jsx`
5. **Expense Approval / Detail** (`expense_detail_screen.dart`) — uses `expense_approval.jsx`
6. **Groups List + Group Detail** (`groups_list_screen.dart`, `group_detail_screen.dart`)
7. **Onboarding** (new screen — add to your auth/router flow)
8. **Settings / Profile**, remaining screens

### 5. Useful follow-up prompts

If Claude gets the look but misses interactions:

> Now compare against the JSX again. The Approve button should show the live amount ("Approve · RM 248.40"), and the Reject button should open a confirmation screen with a required reason field + quick chip suggestions. Add those.

If the spacing feels off:

> Re-read the Spacing Scale in the README. Card padding should be 14-18px, screen horizontal padding 20px. Adjust.

If you want it pixel-perfect:

> Open `design_handoff_duitkita_redesign/DuitKita Redesign.html` and take a screenshot of the Add Payment screen. Compare side-by-side with my Flutter version and list differences.

### 6. Tips

- **Don't paste the JSX into Claude as code-to-translate** — Claude reads it better as "design reference, copy the layout, colors, and interaction patterns." Treat the JSX like a Figma frame.
- **Pin screens with `@`** — type `@design_handoff_duitkita_redesign/screens/add_payment.jsx` in the Claude Code input to attach the file to your message.
- **Drag-drop screenshots** — open the HTML prototype, screenshot the screen you want, drag it into the Claude Code chat. It often produces better Flutter output when it sees both the JSX *and* a rendered image.
- **One feature at a time** — "implement the multi-month picker logic in `add_payment_screen.dart`" is a better prompt than "redesign add_payment_screen.dart."
- **Keep the prototype open** — when Claude finishes a screen, run `flutter run` and compare against the HTML side-by-side. Iterate.

---

## What if Claude Code can't read the JSX?
The JSX uses React, but the patterns are framework-agnostic. If Claude gets confused, paste the relevant section of the README (it's plain markdown with measurements, colors, copy) and that section's JSX file. Tell it: *"Use the JSX for layout reference and the README for exact values. Output Flutter widgets."*

---

## Quick reference — what's been designed so far

| Screen | JSX file | Status |
|---|---|---|
| Onboarding carousel | `screens/onboarding.jsx` | ✅ |
| Home / Dashboard | `screens/main.jsx` → `Home` | ✅ |
| Groups list | `screens/main.jsx` → `GroupsList` | ✅ |
| Group detail | `screens/main.jsx` → `GroupDetail` | ✅ |
| Debts & Bills | `app.jsx` → `DebtsScreen` | ✅ |
| Profile | `app.jsx` → `ProfileScreen` | ✅ |
| Add Expense (modal) | `screens/main.jsx` → `AddExpense` | ✅ |
| New Expense (full screen) | `screens/new_expense.jsx` | ✅ |
| Add Payment + multi-month | `screens/add_payment.jsx` | ✅ |
| Expense Approval | `screens/expense_approval.jsx` | ✅ |
| Help overlay | `screens/main.jsx` → `HelpOverlay` | ✅ |
| Empty states | `screens/main.jsx` → `EmptyState` | ✅ |

Not yet designed: Login, Signup, KYC, JDT screens, Settings sub-pages, Group settings, Manage members, Bulk import, QR payment screen.
