# Touch Display Panel

Native SwiftUI **macOS** app for Johan’s second-screen touch display: large-tap system controls + today’s Apple Calendar.

v1 scope is intentionally narrow — see [`docs/v1-scope.md`](docs/v1-scope.md). No daily brief, Reminders, Mem, or Google Calendar in this scaffold.

> **Build/run requires a Mac with Xcode.** This repo was scaffolded on Linux cloud agents; compile and permission prompts only work on macOS.

## Open in Xcode

1. On your Mac, clone this repo.
2. Open **`TouchDisplayPanel/TouchDisplayPanel.xcodeproj`** in Xcode 15+ (macOS 14+ deployment target).
3. Select the **TouchDisplayPanel** scheme and **My Mac** as the run destination.
4. Signing: pick your Team under *Signing & Capabilities* (Automatic signing is enabled). App Sandbox + Calendars entitlement are already set.
5. Press **Run** (⌘R).

## Grant permissions

### Calendar (required for Today)

On first launch, tap **Allow Calendar Access** on the panel, or approve the system prompt.

If previously denied:

1. **System Settings → Privacy & Security → Calendars**
2. Enable **Touch Display Panel**
3. Relaunch the app

The panel lists calendars EventKit already has access to (same set as Calendar.app / Settings).

### Microphone / camera

v1 does **not** request mic or camera recording permission.

- **Mic mute** toggles the **default input device mute** via Core Audio (no capture).
- **Camera** is a privacy helper: it opens **System Settings → Privacy & Security → Camera**. There is no public macOS API to hard-kill the webcam for all apps; a hardware shutter or vendor driver hook is documented in code for later.

## Run on the touch display

1. Connect the second (touch) display and arrange it in **System Settings → Displays**.
2. Launch **Touch Display Panel**.
3. On launch the app tries to place its window **full-bleed on the largest landscape non-main screen**. If only one screen is connected, it uses that screen’s visible frame.
4. For a kiosk feel: move the window to the touch display if needed, then enter full screen (**View → Enter Full Screen** / green button), or keep the borderless-style frame as placed.
5. Prefer launching from the touch display’s Dock / a Shortcut pinned there so focus lands on that screen.

Touch targets are sized ~56pt+; the layout is landscape-first (controls strip on the left, Today on the right).

## What’s implemented vs placeholder

| Feature | Status |
| --- | --- |
| Second-display placement / full-bleed helpers | Implemented (heuristic: largest landscape secondary `NSScreen`) |
| Volume slider + up/down | **Core Audio** default output volume |
| Output mute | **Core Audio** `kAudioDevicePropertyMute` (output) |
| Mic mute | **Core Audio** input mute on default input device (may be unsupported on some Bluetooth/aggregate devices) |
| Camera / webcam privacy | **Placeholder** — opens Camera privacy settings; panel-local “blocked” UI state only |
| Today’s events (time, title, calendar color) | **EventKit** — full access request, day-change + store-change refresh |
| Next-event highlight | Implemented (next non–all-day event whose end is still in the future) |
| Tap event → Calendar / conference URL | Implemented (Meet/Zoom/Teams/Webex/FaceTime URL detection, else `ical://`) |
| Focus / DND | Not in this scaffold |
| Claude brief / Reminders / Mem / Google | Out of scope for v1 |

## Project layout

```
TouchDisplayPanel/
  TouchDisplayPanel.xcodeproj
  TouchDisplayPanel/
    TouchDisplayPanelApp.swift      # App entry + services
    ContentView.swift               # Landscape strip + Today layout
    Views/
      ControlsStripView.swift
      TodayCalendarView.swift
    Services/
      AudioControlService.swift     # Core Audio volume/mute
      MicMuteService.swift          # Core Audio input mute
      CameraPrivacyService.swift    # Settings hook (documented)
      CalendarService.swift         # EventKit
    Helpers/
      DisplayPlacement.swift
    Info.plist                      # Calendar usage strings
    TouchDisplayPanel.entitlements  # Sandbox + calendars
    Assets.xcassets
```

## Hardware / API notes for later

- **Camera kill switch:** replace `CameraPrivacyService.togglePrivacy()` with a Continuity Camera / USB power / vendor SDK call when Johan’s panel hardware exposes one.
- **Per-app meeting mute:** Zoom/Meet in-call mute is separate from system input mute; deep integration would need those apps’ APIs or Accessibility (not preferred for v1).
- **Focus / DND:** `SetFocus` / Intents or FocusFilter APIs — deferred.
