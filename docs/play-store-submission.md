# Nestling — Google Play submission pack

Everything here is content you paste/select in the **Play Console**. None of it
requires code changes. Facts were taken from the app itself: it is fully
offline, stores everything on-device via `SharedPreferences`, and contains no
analytics, ads, crash-reporting, or network calls.

- **App name:** Nestling
- **Package / application ID:** `com.nestling.app`
- **Category (suggested):** Parenting (or Health & Fitness)
- **Contact email:** a.cassianoweber@gmail.com
- **Privacy policy URL:** see "Privacy policy" below.

---

## 1. Privacy policy URL

A ready-to-host policy lives at `docs/privacy-policy.html` in this repo. The
easiest way to get a public URL is **GitHub Pages**:

1. Repo → **Settings → Pages**.
2. **Build and deployment → Source:** *Deploy from a branch*.
3. **Branch:** `main`, **Folder:** `/docs`. Save.
4. After it publishes, your policy URL will be:

   ```
   https://allanweber.github.io/baby-reminder/privacy-policy.html
   ```

Paste that URL into **Play Console → App content → Privacy policy**. (Note: the
file is on the `claude/bundle-import-main-u5gmf4` branch until merged to `main`.)

---

## 2. Data safety form

Play defines "collection" as data **transmitted off the device**. Nestling never
transmits anything, so the top-level answers are "No".

**Play Console → App content → Data safety:**

- **Does your app collect or share any of the required user data types?** → **No**
- **Is all of the user data collected by your app encrypted in transit?**
  → Not applicable (no data is transmitted). If the form forces a choice, this
  is satisfied vacuously; there is no network traffic.
- **Do you provide a way for users to request that their data be deleted?**
  → **Yes** — users delete records in-app, and uninstalling removes all
  on-device data. (There is no server-side data.)

**Notes to keep for yourself (not pasted):**
- Manual JSON export/import is user-initiated and stored wherever the user
  chooses — not collection by the developer.
- Android Auto Backup (`allowBackup=true`) backs up to the *user's own* Google
  account; per Google's guidance this is not developer "collection" either.

---

## 3. Content rating (IARC questionnaire)

**Play Console → App content → Content rating.** Start the questionnaire.

- **Email address:** a.cassianoweber@gmail.com
- **Category:** *Utility, Productivity, Communication, or Other* (Nestling is a
  tracking/utility app). If a "Parenting/Reference" option appears, that is fine
  too.
- Answer **No** to every content question — the app has none of:
  violence, sexuality, profanity, drugs/alcohol/tobacco references, gambling,
  scary/crude content, or hate.
- **Does the app share the user's location with other users?** → **No**
- **Does the app allow users to interact or exchange content?** → **No**
- **Does the app allow the purchase of digital goods?** → **No**

Expected result: **Everyone / PEGI 3 / rated for all ages.**

---

## 4. Target audience and content

**Play Console → App content → Target audience and content.**

- **Target age groups:** select **adult groups only** (e.g. 18+). Nestling is a
  tool for parents/caregivers.
- **Do you want your app to be included in the "Designed for Families"
  program?** → **No.**
- **Does your app appeal to children?** → **No.** (It records information *about*
  an infant but is operated by an adult; the UI, content, and purpose target
  adults.)

Selecting adult-only audience keeps you out of the stricter Families policy
requirements, which is correct for this app.

---

## 5. App access (login)

**Play Console → App content → App access.**

- **All functionality is available without special access** → **Select this.**
  Nestling has no login, account, or gated features; reviewers can use
  everything immediately.

---

## 6. Store listing (text)

**Play Console → Main store listing.**

**App name** (≤30 chars):
```
Nestling
```

**Short description** (≤80 chars):
```
Track baby feeds & diapers with reliable reminders. Fully offline & private.
```

**Full description** (≤4000 chars):
```
Nestling is a calm, one-handed tracker for your baby's feeds — built for tired
parents and the middle of the night.

Log a bottle, formula, or breastfeeding session in a couple of taps, and let
Nestling remind you when the next feed is due. The reminder rings like a proper
alarm — sound, vibration, and a full-screen alert even over the lock screen — so
you never miss it, even if your phone is in your pocket or the app is closed.

Everything stays on your phone. There is no account to create, no sign-in, and
no internet connection required. Your baby's data is yours alone — Nestling has
no ads, no tracking, and no analytics.

FEATURES
• Fast logging of formula, bottle, and breastfeeding sessions
• A reliable "next feed" reminder with a real alarm (sound + vibration)
• Full-screen alarm that shows over the lock screen when a feed is due
• Snooze, dismiss, or nudge a reminder by +5 / +15 / +30 minutes
• Diaper-change logging
• A clean per-day report of the day's feeds
• Adjustable feed interval, alarm sound, and volume
• Light and dark themes
• Manual backup & restore to a file you control — so your history survives a
  reinstall or a new phone
• 100% offline: no account, no server, no ads, no tracking

Nestling is designed for a single baby and a single caregiver, with a gentle,
uncluttered interface that's easy to use with one hand while you're holding your
little one.
```

**Tips**
- App icon in the listing is auto-derived, but you must also upload a **512×512**
  high-res icon (see graphics below).
- Keep the "offline / no tracking" line — it's a genuine differentiator and
  matches your data-safety answers.

---

## 7. Graphic assets (specs + what to provide)

These are images you upload in **Main store listing → Graphics**. Required:

| Asset | Spec | Notes |
| --- | --- | --- |
| **App icon** | 512×512 PNG, 32-bit, ≤1 MB | ✅ **Ready:** `docs/store-assets/icon-512.png` — composited from the app's adaptive-icon layers (regenerate with `docs/store-assets/make_icon512.js`). |
| **Feature graphic** | 1024×500 PNG or JPG | ✅ **Ready:** `docs/store-assets/feature-graphic.png` — brand banner matching the app (regenerate with `docs/store-assets/make_feature_graphic.js`). |
| **Phone screenshots** | 2–8 images, PNG/JPG; 16:9 or 9:16; each side 320–3840 px | Capture on a device/emulator: (1) home with "Next feed in" banner, (2) the log-feed sheet, (3) the full-screen alarm, (4) the daily report, (5) dark mode. |
| **Tablet screenshots** | Optional | Only if you want tablet placement. |

The **feature graphic** (`docs/store-assets/feature-graphic.png`, 1024×500) and
the **512×512 icon** (`docs/store-assets/icon-512.png`) are both ready. The only
remaining assets are the **phone screenshots** — capture those on a device (the
Log-a-feed sheet, daily report, diapers, reminders, and the full-screen alarm all
make good shots).

---

## 8. Sensitive permission declarations 🚩

These are the highest-risk items. Each has a declaration form in the Play
Console; paste the justification text below. An alarm/reminder app qualifies for
all three, but the justification must be explicit.

### 8a. Exact alarm (`USE_EXACT_ALARM` / `SCHEDULE_EXACT_ALARM`)

**Where:** Play Console flags this during review, or under **App content →
sensitive permissions** if prompted. Justification:

```
Nestling is a feeding-reminder app. Its core, user-facing feature is an alarm
that must fire at an exact, user-set time so a parent is reminded to feed their
baby at the correct moment. Inexact alarms would let the reminder drift by
minutes or be deferred by battery optimization, which defeats the app's primary
purpose. The exact-alarm permission is used only to schedule this user-created
feed reminder; it is not used for background data collection or any other
purpose.
```

> Optional hardening: if a reviewer pushes back, you can switch to
> `SCHEDULE_EXACT_ALARM` with the runtime "Alarms & reminders" opt-in (removing
> `USE_EXACT_ALARM`) — that path needs no declaration. Not required for an
> alarm-category app, but it's the fallback.

### 8b. Full-screen intent (`USE_FULL_SCREEN_INTENT`)

**Where:** **Policy → App content → Full-screen intent permission** (Android 14+
declaration). Justification:

```
Nestling's core function includes an alarm-style feed reminder. When a feed is
due, the app posts a full-screen notification so the reminder appears over the
lock screen and wakes the screen, exactly like a clock alarm, ensuring a parent
sees it even when the phone is locked or idle. The full-screen intent is used
only for this time-critical alarm reminder that the user has explicitly
scheduled.
```

### 8c. Foreground service — media playback (`FOREGROUND_SERVICE_MEDIA_PLAYBACK`)

**Where:** **App content → Foreground service permissions**. Declare the type
and description. Justification:

```
When a scheduled feed reminder fires, Nestling plays the alarm sound through a
short-lived foreground service so the audio and vibration play reliably even if
the app is closed or the device is idle. The service runs only while the
reminder is actively ringing and stops as soon as the user dismisses or snoozes
it. It is not used for background audio streaming or any other purpose.
```

> Play may ask for a short screen-recording demonstrating the foreground
> service. A clip of: reminder fires → alarm screen with sound/vibration →
> user dismisses (service stops) covers it.

---

## 9. Other App content declarations (quick answers)

- **Ads:** No, the app contains no ads.
- **Government app:** No.
- **Financial features:** No.
- **Health apps:** If prompted, Nestling is a personal tracking tool, not a
  medical device; it makes no health claims.
- **Data deletion:** covered in §2.

---

## 10. Release checklist

1. Merge `claude/bundle-import-main-u5gmf4` to `main`.
2. Add the four signing secrets (see `app/README.md`), re-run CI, download the
   **`nestling-appbundle`** artifact (the `.aab`).
3. Create the app in Play Console; complete §§1–9 above.
4. Enroll in **Play App Signing** (recommended) when uploading the first bundle.
5. Upload the `.aab` to **Internal testing** first; verify install + the alarm
   on a real device (lock-screen full-screen alarm, sound, vibration).
6. Promote to Production once the content sections are all green.
