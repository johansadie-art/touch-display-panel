# Touch Display Panel

Native SwiftUI **macOS** app for Johan’s second-screen touch display: large-tap system controls, Google Meet-in-Chrome mute/camera, today’s Apple Calendar, and Apple Reminders.

v1 scope — see [`docs/v1-scope.md`](docs/v1-scope.md). No daily brief, Mem, or Google Calendar in this scaffold.

> **Build/run requires a Mac with Xcode.** This repo is edited on Linux cloud agents; compile and permission prompts only work on macOS.

## Open in Xcode

1. On your Mac, clone this repo.
2. Open **`TouchDisplayPanel/TouchDisplayPanel.xcodeproj`** in Xcode 15+ (macOS 14+ deployment target).
3. Select the **TouchDisplayPanel** scheme and **My Mac** as the run destination.
4. Signing: pick your Team under *Signing & Capabilities* (Automatic signing is enabled).
5. Press **Run** (⌘R).

## Grant permissions

### Calendar (required for Today)

On first launch, tap **Allow Calendar Access** on the panel, or approve the system prompt.

If previously denied:

1. **System Settings → Privacy & Security → Calendars**
2. Enable **Touch Display Panel**
3. Relaunch the app

The panel lists calendars EventKit already has access to (same set as Calendar.app / Settings).

### Reminders (required for the right column)

On first launch, tap **Allow Reminders Access** on the panel, or approve the system prompt.

If previously denied:

1. **System Settings → Privacy & Security → Reminders**
2. Enable **Touch Display Panel**
3. Relaunch the app

**Filter shown:** incomplete reminders that are due today/overdue, have priority (`EKReminder.priority != 0`), or undated (no due date). EventKit has no public flagged API, so priority is the stand-in. Each row shows a small right-aligned **Created** stamp from EventKit `creationDate` (same style as due/overdue text). Checkbox marks complete via EventKit; tapping the row opens Reminders.

### Accessibility (required for Meet mute / Meet camera)

Meet buttons send Chrome shortcuts **⌘D** (mute) and **⌘E** (camera). macOS only allows that after Accessibility trust.

1. Tap **Meet mute** or **Meet camera** once — macOS may prompt to open Accessibility settings.
2. Or go to **System Settings → Privacy & Security → Accessibility**.
3. Enable **Touch Display Panel** (add it with **+** if missing; use the built app under `~/Library/Developer/Xcode/DerivedData/…/Build/Products/Debug/` when running from Xcode).
4. Return to the panel and tap again.

If Accessibility is missing, the strip shows a soft-fail hint and a button that opens Accessibility settings. System volume/mute/mic are unchanged and do **not** need Accessibility.

### Automation (optional, improves Meet focus)

On first Meet tap, macOS may ask to allow controlling **Google Chrome** so the panel can select a `meet.google.com` tab before sending keys.

- **System Settings → Privacy & Security → Automation** → Touch Display Panel → enable Google Chrome.
- If Automation is denied, the panel still activates Chrome when possible and posts ⌘D / ⌘E; leave the Meet tab frontmost for reliable results.

### Microphone / camera (system controls)

v1 does **not** request mic or camera recording permission.

- **Mic mute** toggles the **default input device mute** via Core Audio (no capture). Separate from **Meet mute**.
- **Camera** (system) opens **System Settings → Privacy & Security → Camera**. Separate from **Meet camera**.

## Google Meet buttons — how to test

1. Grant Accessibility (and Automation for Chrome if prompted).
2. In **Google Chrome**, join or open a [meet.google.com](https://meet.google.com) call/tab.
3. On the touch panel, tap **Meet mute** → Chrome should toggle in-call mic (⌘D).
4. Tap **Meet camera** → Chrome should toggle in-call camera (⌘E). Claude’s conflicting ⌘E shortcut was removed so Meet receives it.
5. Confirm **Mute** / **Mic mute** on the panel still only affect **system** audio/input, not Meet’s in-call state alone.

**Fallback:** if Chrome Meet isn’t found, bring the Meet tab frontmost yourself; the panel still posts the shortcuts after a soft status hint.

## Run on the touch display

1. Connect the second (touch) display and arrange it in **System Settings → Displays**.
2. Launch **Touch Display Panel**.
3. On launch the app tries to place its window **full-bleed on the largest landscape non-main screen**. If only one screen is connected, it uses that screen’s visible frame.
4. For a kiosk feel: move the window to the touch display if needed, then enter full screen (**View → Enter Full Screen** / green button), or keep the borderless-style frame as placed.
5. Prefer launching from the touch display’s Dock / a Shortcut pinned there so focus lands on that screen.

Touch targets are sized ~56pt+; landscape layout is **controls | calendar | reminders**.

## What’s implemented vs placeholder

| Feature | Status |
| --- | --- |
| Second-display placement / full-bleed helpers | Implemented (heuristic: largest landscape secondary `NSScreen`) |
| Volume slider + up/down | **Core Audio** default output volume |
| Output mute | **Core Audio** `kAudioDevicePropertyMute` (output) |
| Mic mute | **Core Audio** input mute on default input device (may be unsupported on some Bluetooth/aggregate devices) |
| Camera / webcam privacy | **Placeholder** — opens Camera privacy settings; panel-local “blocked” UI state only |
| **Meet mute** (⌘D) / **Meet camera** (⌘E) | **CGEvent** + Accessibility; focuses Chrome Meet tab via AppleScript when Automation allows |
| Today’s events (time, title, calendar color) | **EventKit** — full access; EventKit store-change + day-change + ~60s periodic refresh |
| Day timeline + overlap lanes | Vertical timed grid; concurrent meetings in side-by-side columns |
| Touch **Refresh** | One large Today-header control reloads today’s calendar **and** Apple Reminders; timeline scrolls to now |
| All-day strip | Thin full-width horizontal bars stacked above the hour grid (near-full-day timed items included) |
| Next-event highlight | Implemented (next non–all-day event whose end is still in the future) |
| Tap event → Calendar / conference URL | Implemented (Meet/Zoom/Teams/Webex/FaceTime URL detection, else `ical://`) |
| Apple Reminders (right column) | **EventKit** — incomplete due today/overdue, priority, or undated; toggle complete + open Reminders |
| Focus / DND | Not in this scaffold |
| Claude brief / Mem / Google | Out of scope for v1 |

## Project layout

```
TouchDisplayPanel/
  TouchDisplayPanel.xcodeproj
  TouchDisplayPanel/
    TouchDisplayPanelApp.swift      # App entry + services
    ContentView.swift               # Controls | Today | Reminders
    Views/
      ControlsStripView.swift       # System + Meet controls
      TodayCalendarView.swift       # Day timeline + all-day bars + overlap lanes
      RemindersPanelView.swift      # Apple Reminders list
    Services/
      AudioControlService.swift     # Core Audio volume/mute
      MicMuteService.swift          # Core Audio input mute
      CameraPrivacyService.swift    # Settings hook (documented)
      MeetControlService.swift      # Meet ⌘D / ⌘E via Accessibility
      CalendarService.swift         # EventKit calendar
      RemindersService.swift        # EventKit reminders
    Helpers/
      DisplayPlacement.swift
      DayTimelineLayout.swift       # Multi-column overlap packing + all-day classification
    Info.plist                      # Calendar + Reminders + Apple Events usage strings
    TouchDisplayPanel.entitlements  # Hardened Runtime Apple Events (sandbox off for CGEvent)
    Assets.xcassets
```

## Hardware / API notes for later

- **Camera kill switch:** replace `CameraPrivacyService.togglePrivacy()` with a Continuity Camera / USB power / vendor SDK call when Johan’s panel hardware exposes one.
- **App Sandbox:** left off so Meet CGEvent posting works with Accessibility; re-enable only with a non-sandboxed helper if distribution requires sandboxing.
- **Focus / DND:** `SetFocus` / Intents or FocusFilter APIs — deferred.
