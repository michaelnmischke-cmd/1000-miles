# Trailhead design

Michael chose the **Trailhead** direction on 2026-11-15. The idea: your year is a hiking trail. A route climbs a topographic map, trail signs stand at each milestone, the summit is the goal, and friends appear as hikers on the same ridge.

Mockups (home, leaderboard, home screen widgets, lock screen; light and dark): https://claude.ai/artifact/LSaVxuu7ve9QUrG2kXAY1K (section 2).

This file is the source of truth for the look. Behaviour, data and screens stay as described in the app spec; only the presentation changes.

## Colors

Add these as color sets in `Assets.xcassets` (Any + Dark appearances) and expose them in `Theme` (Shared/Theme.swift, so the widget extension gets them too). The app follows the system light/dark setting. Light is the "home" look.

| Token | Use | Light | Dark |
|---|---|---|---|
| `paper` | Screen background | `#E4EADF` | `#0F1813` |
| `ink` | Primary text, ridge line | `#1C2A22` | `#E4EADF` |
| `inkMuted` | Secondary text, eyebrows | `#5C6E61` | `#8FA596` |
| `contour` | Topo contour lines | `#B4C3B1` | `#1F3027` |
| `trail` | Walked part of trail, "you" pin, accent, app tint | `#C8452C` | `#FF6B4A` |
| `path` | Not-yet-walked trail (dotted), dashed row dividers | `#9FB0A3` | `#3D5246` |
| `track` | Ring tracks, bar tracks, ridge fill | `#C9D3C4` | `#24372D` |
| `forest` | Secondary accent (first goal ring, "High five" text, ahead of pace) | `#2F5D46` | `#7FC79B` |
| `signWood` | Trail sign plates, medium widget background | `#3E2A1F` | `#4A3324` |
| `signText` | Text and inset border on sign plates | `#F1E6C8` | `#F1E6C8` |
| `tabBar` | Tab bar background | `#1C2A22` | `#070D0A` |
| `tabInactive` | Unselected tab items | `#9DB2A3` | `#6F8577` |
| `blaze` | Selected tab, widget progress line on wood | `#F2C14E` | `#F2C14E` |

Behind pace uses `trail`; ahead of pace uses `forest`. Do not use the old orange-to-coral gradient anywhere.

## Type

- **Display:** Big Shoulders Display (Google Fonts, SIL Open Font License, free to bundle). Weights 800 and 900. Bundle the .ttf files in the app and widget targets and list them under `UIAppFonts`. Always UPPERCASE. Used for the big mile number, screen titles, sign plate values, leaderboard ranks and miles, the lock screen-style numbers in widgets.
- **Text:** the system font (SF Pro), regular/semibold/bold. Everything else.
- **Eyebrows:** system font, 10 pt, bold, uppercase, tracking ~1.4, `inkMuted`. Example: "DAY 319 · 2026 TRAIL".
- Sizes (iPhone points): mile number 64 (with the decimal at 24 in `trail` color), screen title 40, sign value 24, leaderboard numbers 22.

Use `.monospacedDigit()` on changing numbers.

## Shapes and textures

- **Topo background:** 10 to 12 gently wavy horizontal contour lines (1 pt, `contour`) drawn behind every main screen with a `Canvas` or `Path`. Static, not interactive.
- **Trail:** a fixed S-shaped `Path` climbing from bottom left to the top. Unwalked part: 5 pt `path` color, round caps, dotted (`dash: [1, 9]`). Walked part: same path trimmed to `fraction`, 5 pt solid `trail`. Animate the trim on appear with a spring like the current ring.
- **Milestone signs:** small wooden signs placed on the path at 10/25/50/75% (100, 250, 500, 750 mi for a 1000 goal) and the summit at 100%. Each is a 1.5 pt post plus a 28×13 rounded (2 pt) plate in `signWood` (summit plate in `trail`) with the mile number in 8 pt bold `signText`. Use `Path.trimmedPath` / point-at-fraction to position them so they follow whatever goal the user sets.
- **"You" pin:** at the trail's current point: 11 pt soft halo (`trail` 25%), 6 pt dot in `trail` with a 2 pt white stroke, and a capsule label in `ink` with "You · 847.3" in `paper`.
- **Sign plates (cards):** replace the old grey rounded cards. `signWood` fill, 6 pt corner radius, a double inset border (2 pt `signText` then 2 pt `signWood`), eyebrow text at 9 pt uppercase, value in display font. Use for "To the summit" (miles left) and "Daily pace".
- **Goal rings ("side trails"):** extra hand-logged goals stay rings, as Michael asked: 40–44 pt rings, 5 pt stroke, round caps, `track` background. Colors cycle `forest`, `trail`, `inkMuted`. Percent inside in display font; name and "372/500" below in caption.
- **Dividers:** dashed 1 pt `path` lines instead of solid separators.
- **Pills (segmented controls):** capsules with a 1.5 pt `ink` border; selected one filled `ink` with `paper` text.

## Screens

### Progress (home)
Top to bottom, on `paper` with the topo background:
1. Eyebrow "DAY 319 · 2026 TRAIL".
2. "MILE 847" in display 64 with ".3" smaller in `trail`.
3. The trail map (about 200 pt tall, full width) with milestone signs and the "You" pin. This replaces the big ring.
4. Two sign plates side by side: "TO THE SUMMIT · 152.7 MI" and "DAILY PACE · 3.3 MI". Under them a one-line pace note: "26.1 mi behind pace" (`trail`) or "12.0 mi ahead of pace" (`forest`).
5. "SIDE TRAILS" eyebrow and a row of up to three goal rings. (Hand-logged goals arrive in a later stage; show this section only once goals exist.)
6. "Play the song" button: full width, 1.5 pt dashed `ink` border, 6 pt radius, uppercase 10 pt bold, music note icon.
7. Below the fold, keep today/week/month and the weekly chart, restyled: bars in `trail`, pace rule dashed `inkMuted`, labels in `inkMuted`.

The old Milestones badge card goes away; the signs on the trail do that job.

### Friends leaderboard
1. Eyebrow "THIS WEEK ON THE TRAIL", title "TRAIL PARTY".
2. Pills: Week / Month / Year / Global.
3. Ridge graphic (about 140 pt): a rising ridge line in `ink` with `track` fill below; each friend is an emoji avatar in a 20 pt `signText` circle placed along the ridge by their share of the leader's miles. You are a 24 pt `trail` circle.
4. List rows: rank (display, `inkMuted`), emoji + name, a small "HIGH FIVE" in `forest` caps after friends' names, miles right-aligned (display). Your row's rank and miles in `trail`. Dashed `path` dividers.

### Tab bar
Background `tabBar`, items `tabInactive`, selected `blaze`. Tabs unchanged: Progress, Friends, Settings.

### Onboarding and Settings
Same tokens: `paper` background with topo lines, display-font title, primary buttons as `trail` capsules with white text, lists on `paper` with dashed dividers. App tint = `trail`.

## Widgets

- **Small:** `paper` background. Eyebrow "MILE", then "847" in display ~40, and a mini trail in the bottom right with the walked part in `trail` and a large `trail` dot ringed in `paper`.
- **Medium:** `signWood` background, `signText` text. "MILE 847.3" in display ~30 left, "152.7 TO GO" eyebrow right. Below, a horizontal dotted trail line with `blaze` progress, tick marks at each milestone, and a `trail` dot at today's position. Footer: "Jan 1 · Today 4.2 mi · Summit".
- **Lock screen (circular, rectangular, inline):** iOS tints these to one color, so use shape and type only: circular = ring + "847 MI" in display; rectangular = "1000 MILES" eyebrow, "847.3 mi" in display, thin progress bar; inline = "847.3 mi · 85% of 1,000".

## Not changing

Data sources, HealthKit logic, goal setting, the song link behaviour, and screen structure. This is a restyle.
