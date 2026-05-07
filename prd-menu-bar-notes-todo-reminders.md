# PRD: Menu Bar Notes, Todos, Reminders, Focus, and Calendar App

## Problem Statement

Users need a compact personal productivity app that stays out of the way during normal work but remains instantly accessible from the macOS menu bar. Existing notes, todo, reminder, calendar, and focus tools often require opening full applications, switching windows, or managing separate workflows. The desired product should make today's practical work visible from the system menu area, show the number of active records directly in the menu bar, and provide a small, system-feeling popover for quick review and capture.

The app should feel like a native macOS utility rather than a large dashboard. It should use system-sized typography, compact spacing, native language selection, and light/dark appearances that match the user's environment. In the pilot, the app should support English, German, Korean, and Chinese localization.

## Solution

Build a native macOS menu bar application for notes, todos, reminders, Pomodoro focus sessions, and upcoming calendar events.

The app lives primarily in the system menu bar. When there are active records, the menu bar item displays a count. Clicking the menu bar icon opens a compact popover styled similarly to macOS system menus. The popover contains, by default:

- A header with a greeting/title and lightweight productivity statistics.
- A notes/todo/reminder card with the current list and an inline add-new-entry control.
- A Pomodoro focus card with timer controls and selectable focus templates.
- A calendar card with upcoming calendar events.
- Footer actions for settings and app information.

The settings window includes:

- General settings: color scheme, card order, automatic updates disabled by default, and launch at login.
- Notes/todo settings: Markdown storage location and global quick-add hotkey.
- Pomodoro settings: feature visibility toggle and configurable timer templates.
- Calendar settings: feature visibility toggle and configurable calendar data sources.

Notes and todos are stored as Markdown records on disk. A user can add a new note or todo directly from the menu popover, and can also open a quick-add flow through a global hotkey. The app language follows the system language when it is one of the supported pilot languages, with a fallback to English.

## User Stories

1. As a macOS user, I want the app to live in the menu bar, so that I can access my notes and focus tools without opening a full window.
2. As a macOS user, I want the menu bar item to show the number of active records, so that I can see whether something needs attention at a glance.
3. As a macOS user, I want the menu bar item to avoid visual clutter when there are no active records, so that it feels like a lightweight system utility.
4. As a macOS user, I want to click the menu bar icon and open a compact popover, so that my daily items are immediately available.
5. As a macOS user, I want the popover to use system-sized fonts, so that it feels consistent with macOS menus.
6. As a macOS user, I want the popover to support light and dark appearances, so that it matches my desktop theme.
7. As a macOS user, I want the app language to follow my system language, so that I do not need to configure language manually.
8. As a pilot user, I want English localization, so that I can use the app in English.
9. As a pilot user, I want German localization, so that I can use the app in German.
10. As a pilot user, I want Korean localization, so that I can use the app in Korean.
11. As a pilot user, I want Chinese localization, so that I can use the app in Chinese.
12. As a user with an unsupported system language, I want the app to fall back to English, so that the interface remains usable.
13. As a user, I want a header with a greeting or title, so that the popover feels personal and oriented around today.
14. As a user, I want lightweight statistics in the header, so that I can quickly understand my progress.
15. As a user, I want to see how many todo/reminder items are complete today, so that I can track momentum.
16. As a user, I want to see unfinished todos in the menu popover, so that I can act without context switching.
17. As a user, I want to see reminders with times, so that time-sensitive items are visible.
18. As a user, I want to mark a todo as complete from the popover, so that the list can be updated quickly.
19. As a user, I want completed todos to remain visually distinguishable from incomplete todos, so that progress is clear.
20. As a user, I want to add a new note directly from the menu popover, so that capture is fast.
21. As a user, I want to add a new todo directly from the menu popover, so that small tasks do not get lost.
22. As a user, I want to add a new reminder directly from the menu popover, so that timed tasks can be captured without opening another app.
23. As a user, I want the add-new-entry control to stay compact, so that it does not dominate the menu.
24. As a user, I want a global hotkey for quick add, so that I can capture an item while working in another app.
25. As a user, I want to configure the quick-add hotkey, so that it does not conflict with my existing shortcuts.
26. As a user, I want hotkey conflicts to be handled clearly, so that I understand why a shortcut cannot be registered.
27. As a user, I want notes and todos stored as Markdown files, so that my data remains portable and inspectable.
28. As a user, I want to choose where Markdown records are stored, so that I can keep them in my preferred folder or sync location.
29. As a user, I want the app to read records from the selected Markdown location, so that existing records can appear in the menu.
30. As a user, I want the app to write record changes back to Markdown, so that external editors and backups remain useful.
31. As a user, I want malformed Markdown records to fail gracefully, so that one bad entry does not break the app.
32. As a user, I want the app to preserve Markdown content it does not own where possible, so that external edits are not casually destroyed.
33. As a user, I want a Pomodoro section in the popover, so that I can start a focus session quickly.
34. As a user, I want the Pomodoro section to show the current timer, so that I know how much focus time remains.
35. As a user, I want to start, pause, resume, and stop a Pomodoro session, so that I can control focus without leaving the menu.
36. As a user, I want selectable Pomodoro templates, so that I can choose different focus durations.
37. As a user, I want to configure Pomodoro templates, so that the timer matches my working style.
38. As a user, I want to hide the Pomodoro card, so that the menu can stay focused on notes if I do not use Pomodoro.
39. As a user, I want Pomodoro state to remain consistent when the popover closes, so that the timer keeps working.
40. As a user, I want calendar events in the popover, so that I can see what is coming next today.
41. As a user, I want upcoming events to show start time, title, and duration, so that I can scan my schedule.
42. As a user, I want to choose calendar data sources, so that only relevant calendars appear.
43. As a user, I want to hide the calendar card, so that the app remains useful even if I do not use calendar integration.
44. As a user, I want the app to request calendar permissions only when needed, so that privacy prompts are understandable.
45. As a user, I want the calendar card to handle denied permissions gracefully, so that the rest of the app still works.
46. As a user, I want an action to open the full calendar app, so that I can jump from a quick view to detailed schedule management.
47. As a user, I want settings accessible from the popover, so that configuration is always easy to find.
48. As a user, I want app information accessible from the popover, so that I can check version and product details.
49. As a user, I want to choose the color scheme, so that I can use light mode, dark mode, or system appearance.
50. As a user, I want the default card order to be notes, Pomodoro, then calendar, so that the menu matches the initial product design.
51. As a user, I want to reorder cards, so that the menu reflects my personal workflow.
52. As a user, I want card order changes to persist, so that I do not have to set them repeatedly.
53. As a user, I want automatic updates to be off by default in the pilot, so that software changes stay under my control.
54. As a user, I want a setting for launch at login, so that the utility can be ready after restarting my Mac.
55. As a user, I want launch-at-login changes to take effect reliably, so that the menu bar app behaves predictably.
56. As a user, I want settings split into General, Notes/Todos, Pomodoro, and Calendar tabs, so that configuration is easy to scan.
57. As a user, I want compact section headers and counters in the popover, so that information density stays high without feeling crowded.
58. As a user, I want keyboard-friendly controls where practical, so that the app remains fast for power users.
59. As a user, I want the popover to stay within reasonable height and scroll if needed, so that it works on smaller screens.
60. As a user, I want the interface to feel visually close to the provided reference, so that it has a polished, modern menu-bar utility look.
61. As a user, I want the app to continue working offline for notes, todos, reminders, and Pomodoro, so that basic productivity is not network-dependent.
62. As a user, I want data and settings changes to be resilient across app restarts, so that my workflow is not lost.
63. As a user, I want errors to be shown quietly and clearly, so that the menu stays compact while still being understandable.
64. As a user, I want the active record count to update after adding, completing, or deleting records, so that the menu bar badge remains accurate.
65. As a user, I want the active record count to update when Markdown records change externally, so that the app reflects my storage folder.
66. As a user, I want the UI to avoid oversized marketing-style panels, so that it feels like a real tool rather than a landing page.
67. As a user, I want reminders to be visible before they are due, so that the menu helps me plan ahead.
68. As a user, I want local notifications for reminders when enabled, so that time-sensitive tasks can interrupt me appropriately.
69. As a user, I want reminder notifications to respect macOS notification permissions, so that system privacy controls remain authoritative.
70. As a user, I want the app to degrade gracefully if notification permissions are denied, so that reminders still appear in the menu.

## Implementation Decisions

- Build a native macOS menu bar application.
- Use a status item for the persistent menu bar presence and badge/count display.
- Use a compact popover for the main interface rather than a full-size dashboard.
- Use native macOS typography sizing and compact menu-like spacing.
- Support system appearance, explicit light mode, and explicit dark mode.
- Default card order is notes/todos/reminders, then Pomodoro, then calendar.
- Persist user settings locally, including appearance choice, card order, feature visibility, storage location, hotkey, launch-at-login preference, Pomodoro templates, and calendar source selection.
- Treat Markdown storage as a core product requirement, not an export-only feature.
- Encapsulate Markdown reading/writing/parsing behind a dedicated records storage module with a small interface for listing, adding, updating, completing, and deleting records.
- Represent notes, todos, and reminders as one record domain with typed records and optional due/reminder metadata.
- Keep the menu bar badge count focused on active, unfinished actionable records by default. Plain reference notes without action state should not inflate the count unless later product work defines a pinned/active-note concept.
- Support external Markdown changes by reloading records when the storage folder changes on disk.
- Encapsulate quick-add behavior behind a capture module that can be opened from both the popover and the global hotkey.
- Register the global hotkey through a dedicated hotkey module that reports conflicts and disabled states to settings.
- Encapsulate Pomodoro logic in a testable timer/session module independent of the UI.
- Pomodoro templates include a name, focus duration, optional short break duration, optional long break duration, and optional cycle count.
- Pomodoro can be hidden from the main popover without deleting existing Pomodoro configuration.
- Encapsulate calendar reads behind a calendar source module so the UI does not depend directly on any one calendar provider implementation.
- Use native macOS calendar permissions and local calendar APIs for the pilot unless a later implementation decision explicitly adds remote calendar providers.
- Calendar can be hidden from the main popover without deleting configured sources.
- Use system language matching with supported localizations for English, German, Korean, and Chinese, falling back to English.
- Treat automatic updates as a settings surface in the pilot, with automatic updates disabled by default.
- Treat launch at login as a user-controlled setting, not a default-on behavior.
- Settings are organized into four tabs: General, Notes/Todos, Pomodoro, and Calendar.
- App information includes at least app name, version, build information where available, and acknowledgements/licenses if third-party dependencies are used.

## Testing Decisions

- Good tests should verify external behavior and user-visible outcomes rather than internal implementation details.
- Test the records storage module with Markdown fixtures covering notes, todos, reminders, completed records, malformed records, and externally modified files.
- Test record count behavior so active, completed, and non-actionable records produce the expected menu bar count.
- Test quick-add flows at the domain level so the same capture operation works from popover input and global hotkey input.
- Test hotkey registration behavior with success, conflict, disabled, and changed-shortcut cases where the chosen hotkey implementation supports automation.
- Test Pomodoro session logic with deterministic time control covering start, pause, resume, stop, template switching, and completion.
- Test settings persistence covering appearance mode, card order, feature visibility, storage location, hotkey, launch at login, Pomodoro templates, and calendar sources.
- Test localization lookup and fallback behavior for supported and unsupported system languages.
- Test calendar integration through a source abstraction using fake calendar data rather than relying only on real system calendars.
- Test permission-denied calendar behavior so the popover remains usable.
- Add UI-level smoke tests for the main popover composition, settings tabs, compact layout, light/dark appearance, and feature card visibility.
- Add manual QA checks on real macOS for menu bar badge behavior, popover placement, global hotkey behavior, launch at login, calendar permission prompts, and notification permission prompts.

## Out of Scope

- Mobile apps.
- Web app or browser-based implementation.
- Cloud sync as a first-party service.
- Multi-user collaboration.
- Rich-text editing beyond Markdown-backed records.
- Full calendar editing inside the app.
- Full replacement for Apple Calendar, Reminders, or Notes.
- AI summarization, prioritization, or task extraction.
- Recurring task rules beyond what is necessary for basic reminder records.
- Complex project management features such as boards, dependencies, estimates, or team assignment.
- Custom visual themes beyond light, dark, and system appearance in the pilot.
- Additional pilot localizations beyond English, German, Korean, and Chinese.
- Automatic update implementation if no update distribution channel is selected during implementation; only the setting surface is required for the pilot.

## Further Notes

- Initial workspace inspection found no existing app code. The PRD is therefore written as a greenfield product specification.
- The screenshots imply macOS and a native menu bar experience; this PRD assumes macOS as the pilot platform.
- The exact Chinese localization variant should be confirmed before implementation. Simplified Chinese is a reasonable pilot default if no other requirement is given.
- The visual direction should follow the reference images in density and hierarchy, but the implemented UI should stay compact and use system-sized menu typography.
- A later implementation plan should confirm the technology stack, distribution channel, update framework, and exact Markdown record schema before coding begins.
- GitHub issue submission is not possible from the current workspace yet because the repository has no GitHub remote target.
