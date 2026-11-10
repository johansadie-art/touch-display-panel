# v1 scope — Controls + Calendar

Second-screen touch panel only. Large tap targets; not designed for the main display or mouse-first use.

## In scope

- System controls: volume up/down or slider, mute, mic mute, webcam/camera privacy toggle (real APIs where straightforward; document hardware hooks otherwise)
- Google Meet-in-Chrome controls: **Meet mute** (⌘D) and **Meet camera** (⌘E), separate from system mute/mic/camera; Accessibility required
- Today’s Apple Calendar via EventKit: request access, day timeline of today’s events (time, title, calendar color, duration-sized blocks), side-by-side lanes for overlaps, highlight next event, tap opens Calendar or a conference URL

## Out of scope

- Claude daily brief, Apple Reminders, Mem, email, Google Calendar
- Focus / DND (optional later)
- Main-display / trackpad-first UI

## Acceptance

1. App opens full-screen or borderless on the designated second display
2. Volume and mute change Mac audio from the panel
3. Meet mute / Meet camera send ⌘D / ⌘E to a focused Chrome Meet tab (soft-fail hint if Accessibility is denied)
4. Today’s Apple Calendar events load on a day timeline (overlap lanes) and update on day change / EventKit notify
5. Tapping an event opens Calendar (or the conference URL when available)
