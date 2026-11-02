# How to apply the Trips module in Claude Code (VS Code)

## What's in this bundle
- `README.md` — full spec: screens, tokens, interactions, Firestore model (**source of truth**)
- `Trip Module Prototype.html` — open in Chrome to click the end-to-end flow
- `Trip Module.html` — 4-up static overview
- `trip-module/screen.jsx`, `home-redesign/base.jsx` — design-reference React (treat like Figma frames)
- `trip_models.dart` — starter `TripModel` / `ItineraryStop` / `TripMaps` you can drop into `lib/models/`

These are **design references**, not code to copy. Your job is to build the feature as Flutter widgets under `lib/features/trips/`, reusing `DT`/`DS` tokens and your existing service/stream patterns.

---

## Step-by-step

### 1. Drop the bundle into the repo
```
duitkita/
├── lib/
├── design_handoff_trip_module/   ← here
└── pubspec.yaml
```

### 2. Preview
Open `design_handoff_trip_module/Trip Module Prototype.html` in Chrome and keep it visible. Flow: My Trips → tap the Langkawi card → Itinerary → tap a stop (Stop detail) → back → "Add a stop". Tap day tabs to switch days; tap "Navigate this day" and the Maps buttons to see the deep links.

### 3. Dependencies
Ensure these are in `pubspec.yaml` (you already use `google_fonts`, `cloud_firestore`):
- `url_launcher` — to open Google Maps links
- (optional) `google_maps_flutter` / `flutter_static_map` — only if you want a real inline map on Stop detail instead of the stylised preview

### 4. Claude Code prompts — go feature-first, then screen by screen

#### Prompt 1 — Models & service
> Read `design_handoff_trip_module/README.md` (Firestore model + State management sections) and `design_handoff_trip_module/trip_models.dart`.
>
> Add `lib/models/trip_model.dart` and `lib/models/itinerary_stop.dart` based on that starter, matching the fromMap/toMap style of `lib/models/group_model.dart`. Then add `lib/services/trip_service.dart` following `lib/services/group_service.dart`: `streamTrips()` for the current user, `getTrip(id)`, `createTrip(...)`, and `streamStops(tripId)` over the `trips/{tripId}/stops` subcollection. Show me the plan first.

#### Prompt 2 — My Trips list
> Read the **My Trips** section of the README and `screen.jsx` → `TripsList` / `TripCard`.
>
> Create `lib/features/trips/trips_list_screen.dart`. Match the design EXACTLY using `DT`/`DS` tokens: header with a navy "New" button; Upcoming/Past sections; trip cards with a gradient band (emoji tile + name + where), a meta row (date + status pill coloured by status), divider, and a people row (overlapping avatars + traveller/stop counts). Tapping a card pushes the Itinerary screen. Wire it to `TripService.streamTrips()`.

#### Prompt 3 — Itinerary (the core screen)
> Read the **Itinerary** section of the README and `screen.jsx` → `Itinerary` / `Stop` / `DayTab`.
>
> Create `lib/features/trips/itinerary_screen.dart`. Navy gradient header (trip name, range, share, status pill, avatar stack, stop/day counts). A horizontally-scrolling day-tab strip with local selected-day state. For the selected day: a day-header row with **daily drive totals** (summed legMinutes/legKm), a **"Navigate this day"** banner that launches `TripMaps.dayRoute(...)` via `url_launcher`, then a **timeline** — time column + coloured rail dot + tappable stop card, with a leg pill above the card when `legMinutes/legKm` are set. Type→colour map is in the README. Tapping a stop pushes Stop detail. Include the dashed "Add a stop" row and the footer (Add stop + wallet button placeholder).

#### Prompt 4 — Stop detail
> Read the **Stop detail** section and `screen.jsx` → `StopDetail`.
>
> Create `lib/features/trips/stop_detail_screen.dart`. Navy hero (type icon tile, title, type pill + time). Body: Location card (with leg pill), About section, and a map preview area — use a placeholder container for now (I'll swap in a real map later). Footer: "Open in Maps" and "Directions" buttons calling `TripMaps.search(...)` / `TripMaps.directions(...)` with `launchUrl(..., mode: LaunchMode.externalApplication)`.

#### Prompt 5 — New Trip & Add a stop (forms)
> Read the **New Trip** and **Add a stop** sections + `screen.jsx` → `NewTrip` / `AddStop`.
>
> Create `lib/features/trips/new_trip_screen.dart` and `lib/features/trips/add_stop_screen.dart`. Reuse your existing form widgets (`lib/widgets/floating_field.dart`) where they fit. New Trip: name, destination chips (add/remove), start/end date pickers, traveller picker, status segmented toggle; Create → writes the trip and pushes Itinerary. Add a stop: day chip picker, time, title, place, type chips, note; Save → writes to `trips/{tripId}/stops`. Match spacing and the type-chip colours from the README.

#### Prompt 6 — Wire into navigation
> Add a Trips entry point. Either add a Trips tab to `lib/screens/main_navigation.dart` or a card/section on the Home screen that pushes `TripsListScreen`. Follow the existing nav pattern.

### 5. Drive estimates — do it properly in production
The prototype hard-codes leg times/distances as strings. In the app, prefer computing them from the **Google Directions API** (or `google_maps_flutter` distance utilities) and store `legMinutes:int` + `legKm:double` on each stop, formatting in the UI. If you keep manual values, that's fine — just store the two numbers, not a string.

### 6. Tips
- Treat the JSX as a Figma frame — copy layout, colours, and interaction patterns; don't translate it line-by-line.
- Pin files with `@design_handoff_trip_module/...` in Claude Code.
- One screen at a time; run `flutter run` and compare against the open HTML prototype.
- Everything uses tokens you already have — if a value looks new, check `DT`/`DS` first.

---

## Suggested order
1. Models + `TripService`
2. My Trips list
3. Itinerary
4. Stop detail
5. New Trip + Add a stop
6. Navigation entry point
7. (later) Trip expense split — reuse the group/expense engine, `travellerIds` are your members
