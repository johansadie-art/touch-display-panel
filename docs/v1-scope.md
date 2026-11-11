# v1 scope — Controls + Calendar + Reminders

Second-screen touch panel only. Large tap targets; not designed for the main display or mouse-first use.

## In scope

- System controls: volume up/down or slider, mute, mic mute, webcam/camera privacy toggle (real APIs where straightforward; document hardware hooks otherwise)
- Google Meet-in-Chrome controls: **Meet mute** (⌘D) and **Meet camera** (⌘E), separate from system mute/mic/camera; Accessibility required
- Today’s Apple Calendar via EventKit: request access, day timeline of today’s events (time, title, calendar color, duration-sized blocks), side-by-side lanes for overlaps, compact **all-day horizontal bars** above the hour grid, highlight next event, auto-refresh (store + ~60s) and touch Refresh, tap opens Calendar or a conference URL
- Apple Reminders via EventKit (right column): incomplete reminders that are **due today/overdue**, **priority** (`EKReminder.priority != 0`; EventKit has no public flagged API), or **undated**; large touch rows; checkbox toggles complete; row opens Reminders

## Out of scope

- Claude daily brief, Mem, email, Google Calendar
- Focus / DND (optional later)
- Main-display / trackpad-first UI

## Acceptance

1. App opens full-screen or borderless on the designated second display
2. Volume and mute change Mac audio from the panel
3. Meet mute / Meet camera send ⌘D / ⌘E to a focused Chrome Meet tab (soft-fail hint if Accessibility is denied)
4. Today’s Apple Calendar events load on a day timeline (overlap lanes) and update on day change / EventKit notify / light periodic refresh; touch **Refresh** reloads and scrolls to now; all-day items are thin horizontal bars, not tall blocks
5. Tapping an event opens Calendar (or the conference URL when available)
6. Right column shows matching incomplete Apple Reminders; tap checkbox completes (when EventKit allows); tap row opens Reminders
