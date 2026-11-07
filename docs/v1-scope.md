# v1 scope — Controls + Calendar

Second-screen touch panel only. Large tap targets; not designed for the main display or mouse-first use.

## In scope

- System controls: volume up/down or slider, mute, mic mute, webcam/camera privacy toggle (real APIs where straightforward; document hardware hooks otherwise)
- Today’s Apple Calendar via EventKit: request access, list today’s events (time, title, calendar color), highlight next event, tap opens Calendar or a conference URL

## Out of scope

- Claude daily brief, Apple Reminders, Mem, email, Google Calendar
- Focus / DND (optional later)
- Main-display / trackpad-first UI

## Acceptance

1. App opens full-screen or borderless on the designated second display
2. Volume and mute change Mac audio from the panel
3. Today’s Apple Calendar events load and update on day change / EventKit notify
4. Tapping an event opens Calendar (or the conference URL when available)
