# Handoff: Trips module

## Overview
A new **Trips** feature for DuitKita: a user creates a trip (name, destinations, dates, travellers), then fills a **day-by-day itinerary**. Each itinerary stop is typed (travel / food / activity / stay / break), carries an optional place, an "about" blurb, a Google Maps deep link, and an approximate drive leg. Days show a running drive-time + distance total and a one-tap "Navigate this day" route that chains every stop as Google Maps waypoints.

It is designed to sit alongside the existing money features so a trip can later own its own expense split (each traveller is already a member list — reuse the group/expense split logic).

## About the design files
The files in this bundle are **design references created in HTML/React** — a live prototype of the intended look and behaviour, **not production code to copy**. The task is to **recreate these screens as Flutter widgets** inside the existing `duitkita/lib` codebase, using its established patterns:
- Colours/spacing from `lib/config/design_tokens.dart` (`DT`, `DS`) and `lib/config/app_theme.dart`
- Feature-folder layout under `lib/features/<feature>/`
- Firestore-backed models in `lib/models/` + a service in `lib/services/`
- `google_fonts` Manrope, already the app font

Open **`Trip Module Prototype.html`** in Chrome to click through the real flow. `Trip Module.html` shows all four base screens side-by-side.

## Fidelity
**High-fidelity.** Final colours, typography, spacing, icons and interactions. Recreate pixel-for-pixel using the existing `DT`/`DS` tokens — every value below maps to a token you already have.

---

## Screens / Views

### 1. My Trips (`TripsList`)
- **Purpose:** entry point — see all trips, open one, or create a new one.
- **Layout:** `StatusBar` → header row (title "Trips" 26/800/-0.6, subtitle 13/600/`textSecondary`, right-aligned **New** button: 42h, radius 13, `DT.text` fill, white label + plus icon) → scroll area (`DT.bg`, 20px h-pad) with two sections: **Upcoming** and **Past trips** (past at 0.85 opacity) → `BottomNav` → home indicator.
- **Trip card:** radius 18, 1px `DT.border`, `DT.shadow`.
  - **Coloured band** (62h): gradient by trip, 16px h-pad; 40×40 white-90% rounded tile with emoji, name (15.5/800/white) + where (11.5/600/white-82%).
  - **Meta row** (12×16 pad): calendar icon + date range (13/700) + status pill (10.5/800, colour by status: Tentative→`warning`/`warningSoft`, Confirmed→`accentDeep`/`accentSoft`, Settled→`textSecondary`/`surfaceAlt`).
  - Divider, then **people row:** overlapping avatar stack (26px, -10 overlap, 2px surface ring) + "N travellers" + route icon + "N stops".
  - **Whole card is tappable → Itinerary.**

### 2. New Trip (`NewTrip`)
- **Purpose:** create the trip shell.
- **Layout:** `StatusBar` → `BackHeader` "New trip" (back → My Trips) → scrollable form → sticky footer CTA.
- **Fields** (label 12.5/700/`textSecondary`, 7px gap):
  - **Trip name** — big input (16px), edit icon, radius 13, 1px border.
  - **Destinations** — wrap of removable pin chips (`primarySoft` bg, 13/700) + a dashed "Add" chip. Hint below.
  - **Start / End date** — two inputs side-by-side, calendar icon.
  - **Travellers** — row with avatar stack (34px) + "N added" + 34×34 `accentSoft` add button.
  - **Status** — two-segment toggle (Tentative / Confirmed): active = `DT.text` fill/white; inactive = surface + border.
- **Footer:** full-width 52h CTA, `DT.text`, "Create & add itinerary" + arrow → **Itinerary**.

### 3. Itinerary (`Itinerary`)
- **Purpose:** the core view — a typed timeline per day.
- **Header (navy gradient `DT.headerGradient`):** `StatusBar(dark)` → `BackHeader(onDark)` with trip name + date range and a share button (back → My Trips) → status pill + destinations line → avatar stack + "N stops" + "N days".
- **Day tab strip** (`DT.bg`, bottom border): horizontally-scrolling tabs, each 58 min-width, radius 14 — "Day N" / date number / weekday. Active = `DT.text` fill/white. **Tapping a tab switches the day (local state).**
- **Day body** (`DT.bg`, 20px pad):
  - **Day header row:** "{Weekday}, {date} · Day N" (15/800) with a sub-line of **daily totals** — clock icon + summed drive time, car icon + summed km (only when > 0). Right: "N stops".
  - **"Navigate this day" banner:** `accentSoft` bg, 1px `accent` border, radius 14 — 36×36 `accentDeep` tile with route icon, title (13.5/800/`accentDeep`) + "Opens the full route in Google Maps", up-right arrow. **Links to a Google Maps directions URL chaining all mappable stops as origin → waypoints → destination.**
  - **Timeline:** each **stop** = left time column (60w, right-aligned, 12.5/800) · a rail dot (12px, type colour, 3px bg ring + 1.5px colour ring) with a connecting line · a card. Above the card, when a leg exists, a small pill: car/ferry icon + "~1 h 40 · 155 km". **Card is tappable → Stop detail**; shows 38×38 type-soft icon tile, title (13.5/700), optional note (11.5/`textSecondary`), trailing chevron.
  - **Add-a-stop** dashed button, inset to align with cards.
- **Footer:** "Add stop" primary (`DT.text`) + a 50×50 `accentSoft` wallet button (hook point for trip expenses).

### 4. Stop detail (`StopDetail`)
- **Purpose:** what the place is + navigate to it.
- **Header (navy gradient):** back → Itinerary, "Stop details" / trip name; then a hero row: 56×56 white-14% tile with the type icon, stop title (20/800), a type pill + time chip.
- **Body** (`DT.bg`): **Location** card (pin icon, "LOCATION" label, place name) with the leg estimate pill on the right when present → **About this place** section (label + 14.5/1.55 body copy) → a **stylised map preview** (128h, gradient bg with faint SVG road lines + a centred pin; "Approx. location · tap below to open"). *In Flutter, replace this preview with a real static-map image or a `google_maps_flutter` mini-map if desired.*
- **Footer:** two links — **Open in Maps** (`surfaceAlt`, search URL) and **Directions** (`DT.text`, driving directions URL). Both open the external Google Maps app/site.

### 5. Add a stop (`AddStop`)
- **Purpose:** create/edit an itinerary stop.
- **Layout:** `StatusBar` → `BackHeader` "Add a stop" / trip name (back → Itinerary) → form → sticky Save footer (→ Itinerary).
- **Fields:** **Day** (horizontal chip picker, active = `DT.text`) · **Time** (clock input) · **What's happening?** (big input) · **Place** (pin input, hint) · **Type** (5 chips travel/food/activity/stay/break — active chip uses that type's colour + soft bg + 1.5px coloured border) · **Note** (multiline).

---

## Interactions & behaviour
- **Navigation graph:** My Trips ⇄ New Trip → Itinerary; Itinerary ⇄ Stop detail; Itinerary ⇄ Add a stop; every screen has a back arrow. In the prototype this is a single `TripApp` router with a `go(screen, payload)` callback; in Flutter use your existing `Navigator`/routes.
- **Day switching:** local state on the Itinerary; no fetch per day if stops are loaded with the trip.
- **Google Maps links** (open externally via `url_launcher`):
  - Search: `https://www.google.com/maps/search/?api=1&query=<ENCODED place query>`
  - Directions: `https://www.google.com/maps/dir/?api=1&destination=<ENCODED>&travelmode=driving`
  - Whole-day route: `https://www.google.com/maps/dir/?api=1&travelmode=driving&origin=<first>&destination=<last>&waypoints=<A>%7C<B>%7C…` (exclude "break"/prayer stops; skip if < 2 mappable stops).
- **Leg / daily totals:** in the prototype these are hard-coded estimates per stop and summed with a regex parser. **In production, prefer deriving them** from the Directions API (or `google_maps_flutter` / a distance-matrix call) rather than storing strings. If you keep manual estimates, store `legMinutes:int` and `legKm:double` on the stop and format in the UI.
- **Type → colour map:** travel `info`/`infoSoft`, food `warning`/`warningSoft`, activity `catGroups`/`catGroupsSoft`, stay `accentDeep`/`accentSoft`, break `textSecondary`/`surfaceAlt`.

## State management
Follow the existing pattern (services + controllers over Firestore streams). Suggested:
- `TripService` — CRUD trips for the current user; `streamTrips()`, `getTrip(id)`, `createTrip(...)`.
- Itinerary stops as a **subcollection** `trips/{tripId}/stops` (or an embedded `days` array if trips stay small). Stream stops for a trip, group by `day` in the UI.
- Local UI state only for: active day tab, selected type/day in Add-a-stop, "copied" toggles.

## Firestore model (suggested, mirrors `GroupModel` style)
```
trips/{tripId}
  name: string
  destinations: string[]           // ["Perlis","Kedah","Penang","Perak"]
  startDate: Timestamp
  endDate: Timestamp
  status: string                   // "tentative" | "confirmed" | "settled"
  bandGradient: string?            // preset key for the card colour
  emoji: string?                   // "🦅"
  createdBy: string
  travellerIds: string[]
  createdAt / updatedAt: Timestamp

trips/{tripId}/stops/{stopId}
  day: int                         // 1..N   (or dayDate: Timestamp)
  order: int                       // sort within the day
  time: string                     // "10:00 AM"  (or minutesFromMidnight:int)
  title: string
  note: string?
  type: string                     // travel|food|sight|stay|prayer
  icon: string                     // glyph key
  placeQuery: string?              // for Google Maps
  about: string?
  legMinutes: int?                 // drive from previous stop
  legKm: double?
```
A Dart `TripModel` + `ItineraryStop` scaffold is provided in **`trip_models.dart`** in this bundle — align its `fromMap`/`toMap` with your other models.

## Design tokens (all already in `DT` / `DS`)
- Surfaces: bg `#F2F4F7`, surface `#FFFFFF`, surfaceAlt `#F7F9FB`, border `#E6EAF0`, borderStrong `#D1D7E0`
- Text: `#0B1F3A` / `#5B6B82` / `#8B97AA`
- Brand: primary/text `#0B1F3A`, accent `#00C2A8`, accentSoft `#E0F7F2`, accentDeep `#008C7A`, primarySoft `#E8ECF3`
- Status: warning `#F59E0B`/soft `#FEF3DC`, info `#3B82F6`/soft `#E8F0FE`, catGroups `#5B6FFF`/soft `#ECEFFF`
- Header gradient: `#0B1F3A → #12294E` (155°)
- Radii: cards 14–18, hero tiles 11–16, chips 999. Screen h-pad 20. Card pad 11–16.
- Type: Manrope. Weights 500/700/800. Sizes used: 26 / 20 / 15.5 / 14.5 / 13.5 / 12.5 / 11.5 / 11 / 10.5.

## Assets
No raster assets. All icons are inline SVG line-icons defined in `trip-module/screen.jsx` (`TIcon`) + the base set in `home-redesign/base.jsx` (`Icon`). Recreate as Flutter `Icon`s (Material/Lucide) or `CustomPainter`s. Emoji come from the system font.

## Files in this bundle
- `Trip Module Prototype.html` — clickable end-to-end flow (open this)
- `Trip Module.html` — 4-up static overview of the base screens
- `trip-module/screen.jsx` — all Trip screens (source of truth for layout, data, maps helpers)
- `home-redesign/base.jsx` — shared chrome + tokens (`C`, `Icon`, `Avatar`, `StatusBar`, `BottomNav`, `Phone`)
- `trip_models.dart` — starter Dart models
- `HOW_TO_USE_WITH_CLAUDE_CODE.md` — step-by-step Claude Code prompts
