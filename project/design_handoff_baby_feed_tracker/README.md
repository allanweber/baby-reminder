# Handoff: Baby Formula Feeding Logger

## Overview
A mobile app for logging baby formula bottle feeds (date, time, amount, duration, notes), with an automatic next-feed reminder and a per-day report. Single baby/single user. Designed to be built as a native (or cross-platform) mobile app for Android, with iOS as a stretch goal, packaged via GitHub Actions CI.

## About the Design Files
The bundled file (`Baby Feed Tracker.dc.html`) is a **design reference built in HTML/React** — an interactive prototype showing intended look, copy, layout and behavior. It is not production code to embed as-is. The task is to **recreate this design natively** using the target stack's normal patterns:
- Recommended: **Flutter** or **React Native**, both of which build to Android via GitHub Actions easily and to iOS if/when there's access to Apple signing.
- If the team already has an existing app/codebase, use its existing environment and libraries instead.

## Fidelity
**High-fidelity.** Colors, type, spacing, copy, and all interaction states shown in the prototype are final — recreate them pixel-accurately. The prototype is scaled to a 412×892 device canvas (a Pixel-class phone); treat that as the reference viewport and let the native layout adapt responsively to other phone sizes.

## Screens / Views

### 1. Home
- **Purpose**: At-a-glance status + fastest possible path to logging a feed, reachable one-handed.
- **Layout**: Single scrollable column. Top header (greeting + date), reminder/quick-log banner, 3-up stats row, "Today's feeds" list. Fixed bottom tab bar (Home / Daily report). Floating action button (FAB) bottom-right, thumb reach, above the tab bar.
- **Header**: Title = `"{babyName}'s feeds"` if a name is set in Settings, else `"Today's feeds"`. Baloo 2, 700, 26px, color `#4A3B36`. Below: full date (e.g. "Thursday, July 23") — Nunito 600 14px `#9C8A82`. Below that, a small italic time-of-day phrase (not a generic "good afternoon" — phrased around the baby's day): "Off to a gentle start this morning" / "Cruising through the afternoon" / "Winding down for the evening" — Nunito 600 13px `#B7A79E`. Settings cog button top-right, 40×40 circle, background `#EFE4DB`, gear icon stroke `#8B7A73`.
- **Reminder banner** (rounded 24px card, margin 12/20/0):
  - Active/counting-down state: background `#F3EDE6` (or `#F9E2DC` + pulsing dot when overdue). Small dot (accent color, or coral `#D97B67` pulsing when overdue) + label "Next feed in" / "Feed overdue" (13px 700 `#7A6A62`) + big countdown value (Baloo 2 700 22px `#4A3B36`, format "Xh Ym" or "Due now"). Below: full-width primary button **"Log feed now"** (17px 800, white on accent color, 18px radius, drop shadow), then a row of two secondary buttons "Snooze 15m" and "Dismiss" (13px 700).
  - Dismissed/no-timer state: same card slot shows just the same full-width primary **"Log feed now"** button — this button is never absent from the home screen.
- **Stats row**: 3 equal white rounded-18px cards, shadow `0 3px 14px rgba(74,59,54,0.06)`: Today's intake (ml/oz total), Feeds today (count), Avg gap (average interval between feeds, "Xh Ym" or "—" if <2 feeds).
- **Today's feeds list**: reverse-chronological cards (white, 20px radius). Each row: 38×38 rounded-14px icon tile (tinted per feed type) with a small solid dot in the type's accent color; amount + type label (15px 700 `#4A3B36` / `#B7A79E`); time (12h, e.g. "6:30 AM") + optional note/duration suffix (12.5px 600 `#9C8A82`); a small "×" delete button (30×30, `#F3EDE6` bg, `#B7726A` text) which opens a delete-confirmation dialog, not an immediate delete. Tapping the row body (not the × ) opens the edit sheet prefilled.
- **FAB**: 62×62 circle, accent color background, drop shadow. Icon: a simple line-drawn baby bottle (white stroke) with a small white circular "+" badge overlapping its bottom-right corner. Opens the log sheet for a new entry.
- **Bottom tab bar**: white background, top hairline border `#F0E6DD`. Two tabs, each icon (house / calendar) stacked above a 12.5px 700 label; active tab colored with the accent color, inactive `#B7A79E`.

### 2. Log Feed sheet (modal, bottom sheet, opened from FAB or a feed row or "Log feed now")
- **Layout**: Bottom sheet sliding up (28px top corner radius), drag handle bar, title "Log a feed" / "Edit feed" (Baloo 2 700 19px).
- **Feed type**: 3 segmented pill buttons, equal width, gap 8px: Formula / Breast milk / Breastfeeding. Selected pill fills with that type's accent color + white text; unselected are white with a light `#EFE4DB` border and `#8B7A73` text. Default selection: Formula (configurable).
  - Type accent colors: Formula `#E39C8B`, Breast milk `#7FA377`, Breastfeeding `#A98FC4`.
- **Date / Time**: two native date/time inputs side by side, each labeled ("DATE"/"TIME", 12px 700 `#9C8A82`), defaulting to today / now. Selecting a value applies immediately — no separate "set/confirm" step.
- **Amount** (hidden entirely when type = Breastfeeding, since that type is duration-only): white rounded-20px card. Header row: "AMOUNT" label + a ml/oz unit toggle pill (two small buttons in a `#F3EDE6` track; the active unit is white with accent-colored text). Below: a stepper — big "–" circle button (44px, `#F3EDE6`), the current value centered (Baloo 2 700 32px, e.g. "120 ml" or "4.1 oz"), big "+" circle button (44px, accent color bg, white icon). Step size ~10ml (or ~15ml equivalent in oz mode). The last-used unit is remembered as the default for the next time the sheet opens.
- **Duration**: white rounded-20px card, label "DURATION (MIN)" when type = Breastfeeding (required, minimum 1) or "DURATION (OPTIONAL)" otherwise, with a small hint line underneath ("How long the feed took" / "How long the feed took, if you tracked it"). Compact stepper on the right: small "–" (36px), value (Baloo 2 700 20px, e.g. "12 m"), small "+" (36px), step 1 minute.
- **Note**: label "NOTE (OPTIONAL)", multiline textarea, placeholder "e.g. spit up a little, fussy before feed…".
- **Validation** (inline red `#B7726A` 13px 700 message above the buttons, blocks save until resolved):
  - Date and time are always required.
  - Amount is required (>0) when type is Formula or Breast milk.
  - Duration is required (>0) when type is Breastfeeding.
- **Footer**: "Cancel" (flex 1, `#EFE4DB` bg, `#7A6A62` text) + "Save feed" (flex 2, accent bg, white text), both 18px radius, 14px vertical padding.

### 3. Delete confirmation (modal, centered)
- Small centered card (22px radius) over a dim scrim. Title "Delete this feed?" (Baloo 2 700 17px), subtext "This can't be undone." (13.5px 600 `#9C8A82`). Two buttons: "Cancel" (`#EFE4DB`) and "Delete" (solid `#C9695C`, white text). Triggered by the × on any feed row (home list and report list); nothing is removed until the user confirms.

### 4. Settings sheet (bottom sheet, opened from the home header cog)
- "Baby's name" text input (placeholder "e.g. Mia"). Used to personalize the home header and the report title; when empty, headers fall back to generic copy ("Today's feeds" / "Daily report").
- "Feed reminder" section: explanatory line + a row of interval preset chips (1.5h / 2h / 3h / 4h / 5h). Selected chip fills with the accent color. Selecting a preset resets the current countdown to start from now at that interval.
- Full-width "Done" button (accent color) closes the sheet.

### 5. Daily report
- **Layout**: same scrollable-column + fixed tab bar + FAB shell as Home (the FAB and tab bar persist across both tabs).
- **Header**: `"{babyName}'s daily report"` if a name is set, else `"Daily report"` (Baloo 2 700 22px).
- **Date nav row**: "‹" / "›" circular buttons (36px, white, soft shadow) either side of a tappable date label; tapping the label opens a native date picker to jump to any date directly (invalid/empty input falls back to today). When the viewed date isn't today, a small "Jump to today" pill button appears just below the nav row.
- **Stats row**: identical 3-card layout to Home's stats row, but scoped to the selected day: Total intake, Feeds, Avg gap.
- **Timeline list**: same card styling as Home's feed list, chronological ascending, for the selected day. Each row also has the × delete button (with the same confirmation dialog) and tapping the row opens the edit sheet.
- **Empty state**: centered muted text "No feeds logged this day." when the selected day has none.

## Interactions & Behavior
- Logging a feed (new, not an edit) recomputes the "next feed" reminder as `feed timestamp + reminder interval` and clears any dismissed/snoozed state.
- Snooze pushes the reminder 15 minutes from now.
- Dismiss hides the countdown banner (replaced by the plain "Log feed now" button, never a blank slot) until the next feed is logged.
- Editing an existing feed does **not** recompute the reminder.
- Countdown ticks live (recommend updating at least once a minute).
- All amounts are stored canonically in ml; the oz display is a conversion (1 oz = 29.5735 ml), and the unit toggle is global (remembers the last choice as the default for next time), not per-entry.
- This prototype simulates the reminder as an in-app banner. **Real push notifications require the native app shell** — implement local/scheduled notifications (Android: `AlarmManager`/`WorkManager` or the RN/Flutter equivalent; iOS: local notifications) that fire at the computed reminder time, even when the app is backgrounded.

## State Management
- `feeds`: list of `{ id, date (YYYY-MM-DD), time (HH:MM 24h), type ('formula'|'breastBottle'|'breastfeeding'), amountMl, durationMin, note }`.
- `babyName`: string, optional.
- `unitPref`: `'ml' | 'oz'`, persisted as the default.
- `reminderIntervalMin`: number (default 180), persisted.
- `nextReminderAt`: timestamp, recomputed on new feed save / snooze / interval change.
- `reminderDismissed`: boolean, reset on new feed save.
- Persist `feeds`, `babyName`, `unitPref`, `reminderIntervalMin` to local on-device storage (this is a single-user, single-baby, offline-first app — no backend needed for v1).

## Design Tokens
- **Colors**: background/cream `#FFF8F2` (page) / `#F3EDE6` (secondary surface), card white `#FFFFFF`, primary text `#4A3B36`, secondary text `#9C8A82`, muted text `#B7A79E` / `#C4B6AC`, borders `#EFE4DB`, error/delete `#B7726A` (text) / `#C9695C` (solid button), overdue accent `#D97B67`.
  - Accent (tweakable, default blush) `#E39C8B`. Alternative curated accents used elsewhere for feed types: sage `#7FA377`, lavender `#A98FC4`. A soft-peach `#D9A441`-family alt accent is also offered as a theme option.
  - Feed type tints (icon tile backgrounds): Formula `#FBEAE5`, Breast milk `#EAF1E6`, Breastfeeding `#EFE7F5`.
- **Typography**: Display font **Baloo 2** (600/700) for headings, numbers, big stats. Body font **Nunito** (400/600/700) for everything else. Base body size 13–15px; large countdown/amount numerals 20–32px.
- **Radius scale**: 10px (small chips) / 14–16px (inputs, small buttons) / 18–20px (cards, primary buttons) / 22–28px (sheets, dialogs).
- **Shadows**: cards `0 2–3px 10–14px rgba(74,59,54,0.05–0.08)`; FAB/primary CTA `0 6–8px 16–20px` in the accent color at ~40–50% opacity.

## Assets
No image assets — all icons (settings gear, home house, report calendar, bottle+plus FAB) are simple line-drawn SVGs, single color, defined inline in the prototype. No illustrations or photography are used; the calm/friendly feel comes from color, type and rounded geometry only.

## Files
- `Baby Feed Tracker.dc.html` — the full interactive prototype (React-based; open directly in a browser). Contains all screens, state transitions, and exact copy referenced above.
