# Phase 8 Pilot QA

Scope: final pilot readiness checks for localization, compact layout, keyboard affordances, and quiet resilience.

## Localization

- Pilot languages: English (`en`), German (`de`), Korean (`ko`), and Simplified Chinese (`zh-Hans`).
- Chinese pilot variant: Simplified Chinese.
- Unsupported system languages should fall back to English.
- Check the complete popover, settings, quick add, app info, hotkey status, notification status, and calendar status text in each pilot language.

## Manual UI Smoke

- Open the menu bar popover in light and dark appearances.
- Confirm notes/todos/reminders, Pomodoro, calendar, footer actions, and header statistics remain compact and readable.
- Add long English, German, Korean, and Simplified Chinese titles; confirm rows wrap without overlapping controls.
- Fill the popover with enough records/events to exceed the visible height; confirm the popover scrolls.
- Use Return to submit popover capture and quick add; use Escape to cancel quick add.
- Open settings and verify tab labels, card ordering controls, hotkey picker/status, folder chooser, Pomodoro templates, calendar access/status, app information, and launch/update toggles.

## Resilience

- No Markdown folder: capture should show a compact storage status and leave the app usable.
- Invalid storage/write failure: notes card should show a compact save failure.
- Hotkey conflict or registration failure: settings should show a compact status.
- Notification denied/unavailable/failure: reminder records should stay visible and the status should remain compact.
- Calendar not determined/denied/unavailable/loading/failure/no events: calendar card should stay compact and the rest of the popover should remain usable.

## Residual

- Terminal tests cover language selection, fallback, localized key coverage, format-string safety, display helper fallbacks, and complete popover card composition.
- Actual macOS screenshot QA for light/dark layout, popover placement, global hotkey behavior, notification prompts, calendar prompts, launch at login, and restart persistence remains manual for the pilot.
