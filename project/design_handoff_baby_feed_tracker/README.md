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

### 1b. Reminders tab (new nav item, left of Feed)
- Bottom nav is now 4 tabs: **Reminders** — **Feed** (larger/bolder — the primary tab) — **Diapers** — **Report**. "Home" was renamed to "Feed."
- Purpose: manage recurring alarms for non-feed care items — medicine, vitamins, tummy time, exercises, activities, diaper, bath, other.
- **Due-now cards** at top (shown only when something is due): category color dot + label, big "Mark done" primary button, "Snooze 15m" / "Dismiss" secondary row. Marking done logs a completion (for the report) and reschedules per the reminder's repeat rule.
- **All reminders list** below: each row shows label, category, schedule summary ("Daily at 9:00 AM" or "Every 8h"), and time until next due. Tap opens edit; × opens the same delete-confirmation dialog pattern as feeds.
- **FAB** on this tab shows a bell icon (instead of the bottle) and opens the Add/Edit Reminder sheet.
- **Add/Edit Reminder sheet**: Label (text input) → Category (8 pill options: Medicine, Vitamins, Tummy time, Exercises, Activities, Diaper, Bath, Other — each with its own accent color) → Mode toggle "Daily at a time" vs "Every N hours" → conditionally either a time picker or an hour stepper → Save.
  - **Validation**: label required. Fixed-time mode: duplicate hh:mm across other fixed-time reminders is blocked with an inline error naming the conflicting reminder — this check does NOT apply to interval-mode reminders (their due time drifts, so it can't collide on a fixed clock time).
  - Interval-mode reminders auto-reschedule +N hours from completion time (same pattern as the feed reminder).

### 1c. Diapers tab (new nav item, between Feed and Report)
- Purpose: log diaper changes (pee/poop/both) with color and amount, for health tracking — logging/reporting only, no schedule or alarm.
- **Accent color**: a distinct teal `#5B94AC` (soft tint `#E4F0F4`) used only for this feature, so it never reads as a Feed or Reminder entry.
- **Stats row**: 3 cards — Changes (teal solid card, white text), Pee (count), Poop (count).
- Full-width primary button **"Log diaper change"** (teal, matches the Log-feed-now button pattern).
- **Today's changes list**: teal-tinted rows (`#E4F0F4` background, not white — this is the visual differentiator from Feed's white cards and Reminders' dashed-border cards): 38×38 teal icon tile (folded-diaper glyph), type label ("Pee"/"Poop"/"Pee & poop"), time + color/amount detail line (e.g. "7:15 AM · Poop · Yellow · Small"), one or two small color-swatch dot badges (8–16px circles, color = the logged pee/poop color, white-ring outline) trailing the row, and the same "×" delete-confirm pattern as feeds/reminders.
- **FAB** on this tab shows the folded-diaper icon and opens the Log Diaper sheet.
- **Log/Edit Diaper sheet** (bottom sheet, same shell as the feed sheet):
  - **Type**: 3 segmented pills — Pee / Poop / Pee & poop.
  - **Date / Time**: same paired native inputs as the feed sheet.
  - **Pee color** (shown when type is Pee or Pee & poop): required toggle, swatch buttons — Clear, Pale yellow, Yellow, Dark amber, Pink/red (the last two flag possible dehydration/blood — not just "healthy" shades). Selected swatch gets a white-ring halo + white checkmark overlay + bold colored label so the selection is unambiguous.
  - **Poop color** (shown when type is Poop or Pee & poop): required toggle, swatch buttons — Yellow, Brown, Green, Pale/white, Black, Red (again spanning concerning colors, not only healthy ones). Same selected-state treatment as pee color.
  - **Poop amount** (shown alongside poop color): optional toggle, Small / Medium / Large; tapping the already-selected pill deselects it.
  - **Note**: optional textarea, same style as the feed sheet's note field.
  - **Validation**: date/time always required; pee color required whenever pee is logged; poop color required whenever poop is logged; amount is optional.
  - **Footer**: "Cancel" + "Save diaper log" (teal accent), same layout as the feed sheet footer.

### 1d. Quick log (ad-hoc category logging, no schedule)
- Purpose: let the caregiver log that a category happened (e.g. "gave vitamins") right now, without creating or touching a recurring schedule.
- **Entry points**: (1) a "Quick log" chip row on the Reminders tab, above "All reminders" — one compact pill per category, excluding Diaper (7 categories: Medicine, Vitamins, Tummy time, Exercises, Activities, Bath, Other), each pill outlined/tinted in its category color. (2) A FAB on the Report screen (Report previously had no FAB) that opens a "Quick log" bottom sheet with the same 7 chips plus a Cancel button.
- **Behavior**: tapping a chip logs instantly — category, today's date, current time, no note — and shows a brief toast ("{Category} logged · {time}") that auto-dismisses after ~1.5s. No sheet/form step for the common case.
- **Backdating**: not offered at log time. To change the date/time of a quick log, tap the row in the report (see below) to edit it after the fact.
- **Report-only visibility**: quick logs never appear in the "All reminders" list (which only shows items with an ongoing schedule) — they only show up in the Daily report, under the Reminders filter, merged into the same time-sorted list as scheduled reminder completions/misses.
- **Distinct report styling**: a quick log renders as a plain solid white card (no dashed border, unlike scheduled-reminder rows) with the category icon tile, label, category, and time — and no "Done"/"Missed" status pill, since there was no schedule to satisfy. Tapping the row opens a compact edit sheet (date + time only); a "×" opens the same delete-confirmation dialog pattern used elsewhere.
- **Reminders stats update**: the Reminders-filter stats row in Daily report now shows three cards instead of two — Completed, Missed, **Logged** (count of quick logs for the viewed day) — so ad-hoc logs never get conflated with schedule completions.

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
- "Dark mode" row: label + description + a pill toggle switch (track = accent color when on, soft neutral when off; white thumb slides left/right). Persists across sessions.
- Full-width "Done" button (accent color) closes the sheet.

### 5. Daily report
- **Layout**: same scrollable-column + fixed tab bar + FAB shell as Home (the FAB and tab bar persist across all three tabs; hidden only in the report itself).
- **Header**: `"{babyName}'s daily report"` if a name is set, else `"Daily report"` (Baloo 2 700 22px).
- **Filter**: 4-way segmented control **All / Feed / Diapers / Reminders** directly under the header (default All). Selected segment fills with the accent color (Diapers segment fills with the teal diaper accent, not the app accent).
- **Date nav row**: "‹" / "›" circular buttons (36px, white, soft shadow) either side of a tappable date label; tapping the label opens a native date picker to jump to any date directly (invalid/empty input falls back to today). When the viewed date isn't today, a small "Jump to today" pill button appears just below the nav row.
- **Stats row**: swaps by filter — Feed/All shows Total intake, Feeds, Avg gap (3 cards); Reminders shows Completed, Missed (2 cards); Diapers shows Total changes (teal solid card), Pee count, Poop count (3 cards).
- **Timeline list**: merged and time-sorted when filter = All.
  - **Feed rows**: unchanged solid white card style (icon tile, amount + type, time + note).
  - **Reminder rows**: visually distinct — dashed border in the category's accent color, category icon tile, label + category, time, and a small status pill ("Done" or "Missed"). Missed reminders (fixed-time reminders whose time passed with no completion logged that day) render at reduced opacity/grayed to distinguish from completed ones.
  - **Diaper rows**: visually distinct from both — solid teal-tinted `#E4F0F4` background (no dashed border, not white), teal icon tile, type label, time + color/amount detail, and trailing color-swatch dot badge(s) showing the exact logged pee/poop color at a glance.
- **Empty state**: centered muted text "Nothing logged this day." when the selected day + filter has no items.

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
- `reminders`: list of `{ id, label, category ('medicine'|'vitamins'|'tummyTime'|'exercises'|'activities'|'diaper'|'bath'|'other'), mode ('fixed'|'interval'), fixedTime (HH:MM, fixed mode only), intervalHours (number, interval mode only), nextDueAt (timestamp), snoozedUntil (timestamp|null), dismissed (boolean) }`.
- `reminderLogs`: append-only completion/log history, `{ id, reminderId (string, or null for a quick/ad-hoc log), label, category, date, time }` — written when a scheduled reminder is marked done, or instantly when a quick-log chip is tapped (reminderId: null marks it as ad-hoc). Drives the report's history rows and the Completed/Missed/Logged counts.
- `diapers`: list of `{ id, date (YYYY-MM-DD), time (HH:MM 24h), type ('pee'|'poop'|'both'), peeColor ('clear'|'pale'|'yellow'|'dark'|'pink'|null), poopColor ('yellow'|'brown'|'green'|'white'|'black'|'red'|null), poopAmount ('Small'|'Medium'|'Large'|null), note }` — logging/reporting only, no scheduling fields.
- `babyName`: string, optional.
- `unitPref`: `'ml' | 'oz'`, persisted as the default.
- `reminderIntervalMin`: number (default 180), persisted.
- `nextReminderAt`: timestamp, recomputed on new feed save / snooze / interval change.
- `reminderDismissed`: boolean, reset on new feed save.
- Persist `feeds`, `diapers`, `babyName`, `unitPref`, `reminderIntervalMin` to local on-device storage (this is a single-user, single-baby, offline-first app — no backend needed for v1).

## Design Tokens
- **Colors**: background/cream `#FFF8F2` (page) / `#F3EDE6` (secondary surface), card white `#FFFFFF`, primary text `#4A3B36`, secondary text `#9C8A82`, muted text `#B7A79E` / `#C4B6AC`, borders `#EFE4DB`, error/delete `#B7726A` (text) / `#C9695C` (solid button), overdue accent `#D97B67`.
  - Accent (tweakable, default blush) `#E39C8B`. Alternative curated accents used elsewhere for feed types: sage `#7FA377`, lavender `#A98FC4`. A soft-peach `#D9A441`-family alt accent is also offered as a theme option.
  - Feed type tints (icon tile backgrounds): Formula `#FBEAE5`, Breast milk `#EAF1E6`, Breastfeeding `#EFE7F5`.
  - Reminder category colors (icon + dashed border + status pill): Medicine `#C9695C`/`#F7E3E0`, Vitamins `#D9A441`/`#FBF0DC`, Tummy time `#8FAE7B`/`#EDF3E6`, Exercises `#6FA8A0`/`#E3F1EF`, Activities `#B08FC4`/`#F0E7F5`, Diaper `#D98E8E`/`#F9E9E9`, Bath `#7FB0C4`/`#E6F1F5`, Other `#A79A8F`/`#EFEAE5`.
  - Diapers feature accent (distinct from the app accent, used only here): `#5B94AC` solid / `#E4F0F4` soft tint.
  - Pee colors: Clear `#F7F6EC`, Pale yellow `#F5E6A3`, Yellow `#E8C547`, Dark amber `#C68A2E`, Pink/red `#C4585A`.
  - Poop colors: Yellow `#D9A441`, Brown `#8B5E3C`, Green `#6B8E4E`, Pale/white `#E5DEC5`, Black `#3A3A3A`, Red `#B23A2E`.
- **Typography**: Display font **Baloo 2** (600/700) for headings, numbers, big stats. Body font **Nunito** (400/600/700) for everything else. Base body size 13–15px; large countdown/amount numerals 20–32px.
- **Radius scale**: 10px (small chips) / 14–16px (inputs, small buttons) / 18–20px (cards, primary buttons) / 22–28px (sheets, dialogs).
- **Shadows**: cards `0 2–3px 10–14px rgba(74,59,54,0.05–0.08)`; FAB/primary CTA `0 6–8px 16–20px` in the accent color at ~40–50% opacity.

## Dark Mode
A dark theme is included, toggled from the Settings sheet (persisted via local storage). Implement as a second token set, not per-component overrides:
- Surfaces: page `#221B19`, card `#352C29`, secondary/inset `#241D1B`, soft `#3D332F`, borders `#453A35`, dividers `#4A3E38`.
- Text: primary `#F3EAE4`, secondary `#B8A99F`, tertiary `#8F8079`, secondary-strong `#C9BAB0`, icon-neutral `#B8A99F`.
- Status: danger `#D97A6C`, danger-text `#E39184`, reminder-due-bg `#4A342E`.
- Diaper-specific: card bg `#2E3A3D`-family (teal-tinted dark), delete bg/text tuned to stay legible on dark.
- Category/type "soft" tint chips (feed-type icon tiles, reminder category chips, diaper swatches) are NOT swapped to fixed dark hexes — they're computed as `color-mix(in srgb, {categoryColor} 24%, {cardBg} 76%)` so any accent stays legible against either surface. Recreate this as a token function, not a lookup table.
- All solid accent colors (feed types, reminder categories, diaper teal, pee/poop swatches) stay the same hex in both themes — only neutrals and soft tints change.

## Missed Reminder → Mark Done Late
Applies to fixed-time reminders only (interval-mode reminders never get a "missed" state).

- A fixed-time reminder is "missed" once its due time has passed for today AND no log exists yet for today. This is independent of whether the due banner was dismissed.
- Shown as a tappable "Missed" indicator/pill in both the Reminders tab (inline tag under the reminder name) and the Daily Report (status pill on the placeholder row).
- Tapping it always opens a confirmation dialog ("Mark as done now?") before logging anything.
- Confirming logs it at the **current** time (never backdated) under **today's actual date** — not the reminder's next scheduled occurrence date.
- The resulting log's status pill reads **"Done (late)"** (distinct warm color) instead of plain "Done", and remains visible/deletable in the Report going forward (delete button now shows for late logs, not just quick-logs).
- The reminder's next occurrence is unaffected — always reschedules to its normal daily fixed time regardless of when today's was completed.

## Add Time to Feed Reminder Countdown
On the home tab's "Next feed in" / "Feed overdue" banner, add three small buttons below the existing Snooze/Dismiss row: **+5m**, **+15m**, **+30m**.
- Tapping one pushes the reminder's next-due time forward by that amount, from its current due time (not from now) — so tapping +15m twice adds 30 minutes total.
- If the reminder was overdue, adding time can move it back into the future; the banner should immediately reflect the new state (overdue pulse/label clears if no longer due).
- This is independent of the interval presets in Settings — it's a one-off nudge to the current countdown, not a change to the default interval.
- Same subtle secondary-button styling as Snooze/Dismiss (transparent/outline, not accent-filled).

## Assets
No image assets — all icons (settings gear, home house, report calendar, bottle+plus FAB) are simple line-drawn SVGs, single color, defined inline in the prototype. No illustrations or photography are used; the calm/friendly feel comes from color, type and rounded geometry only.

## Files
- `Baby Feed Tracker.dc.html` — the full interactive prototype (React-based; open directly in a browser). Contains all screens, state transitions, and exact copy referenced above.
