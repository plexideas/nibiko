# Plan: Menu Bar Notes, Todos, Reminders, Focus, and Calendar App

> Source PRD: [prd-menu-bar-notes-todo-reminders.md](../prd-menu-bar-notes-todo-reminders.md)

## Architectural decisions

Durable decisions that apply across all phases:

- **Platform**: Native macOS menu bar utility. The menu bar status item is the primary app surface; the app does not need a main document window for the pilot.
- **Primary surfaces**: Menu bar status item, compact popover, quick-add panel, settings window, and app information view.
- **Data ownership**: Local-first and offline-first. Notes, todos, reminders, Pomodoro state, preferences, and cached calendar selection work without a network dependency.
- **Authentication**: No app-level accounts, login, or authorization model in the pilot.
- **Record schema shape**: A record has an id, kind, title, optional body, status, created timestamp, updated timestamp, optional due time, optional reminder time, and optional completed timestamp. Record kind is note, todo, or reminder.
- **Markdown storage**: Records are stored in a user-selected Markdown location. The exact serialized Markdown format should be confirmed before implementation, but the app owns a structured subset that it can parse, update, and preserve safely.
- **Settings schema shape**: Settings include appearance mode, card order, feature visibility, Markdown storage location, quick-add hotkey, launch-at-login preference, automatic-update preference, Pomodoro templates, and selected calendar sources.
- **Key models**: AppSettings, MenuCard, Record, RecordKind, RecordStatus, PomodoroTemplate, PomodoroSession, CalendarSource, CalendarEvent, PermissionState, and HotkeyBinding.
- **Menu bar count**: The status item count represents active unfinished actionable records. Plain reference notes do not increase the count unless later product work introduces pinned or active notes.
- **System boundaries**: Use native macOS boundaries for status item and popover behavior, file-system access and watching, global hotkey registration, calendar access, notifications, launch at login, localization, and appearance.
- **Permissions**: Calendar and notification permissions are requested only when the user enables or uses related functionality. Denied permissions degrade the affected card without breaking the rest of the app.
- **Localization**: The app follows the system language for English, German, Korean, and Chinese, with English fallback for unsupported languages.
- **Updates**: Automatic updates are represented as a disabled-by-default preference in the pilot. Implementing real update delivery is outside the pilot unless a distribution channel is chosen.

---

## Phase 1: Menu Bar Shell and Preferences Baseline

**User stories**: 1, 3, 4, 5, 6, 7, 12, 13, 14, 47, 48, 49, 50, 52, 56, 57, 59, 60, 62, 63

### What to build

Create the first demoable native macOS app shell: it launches into the menu bar, opens a compact popover, shows a header with placeholder progress statistics, displays empty placeholder cards in the default order, and exposes settings plus app information. Persist basic preferences for appearance and card ordering so the shell already proves the app's menu-bar-first shape.

### Acceptance criteria

- [ ] The app launches without showing a main document window.
- [ ] A menu bar status item appears and opens a compact popover when clicked.
- [ ] The popover contains a header, notes placeholder, Pomodoro placeholder, calendar placeholder, settings action, and app information action.
- [ ] The popover uses compact system-sized typography and remains within a reasonable height on smaller screens.
- [ ] The settings window has General, Notes/Todos, Pomodoro, and Calendar tabs.
- [ ] Appearance mode can be changed between system, light, and dark, and the choice persists across app restart.
- [ ] Default card order is notes/todos/reminders, Pomodoro, then calendar.
- [ ] Card order can be changed in settings and persists across app restart.
- [ ] English localization and English fallback behavior are wired for the initial shell.
- [ ] App information shows at least app name and version/build information where available.
- [ ] Smoke tests or manual verification cover launch, popover open/close, settings open, app information open, appearance persistence, and card-order persistence.

---

## Phase 2: Markdown Notes and Todos MVP

**User stories**: 2, 15, 16, 18, 19, 20, 21, 23, 27, 28, 29, 30, 31, 32, 61, 64, 65

### What to build

Add the first real records path from storage through UI and back again. The user can choose a Markdown storage location, load notes/todos from it, add a new note or todo from the popover, mark todos complete, and see the menu bar count update from active unfinished actionable records.

### Acceptance criteria

- [ ] The Notes/Todos settings tab lets the user choose a Markdown storage location.
- [ ] The app can create records in the selected Markdown storage location.
- [ ] Existing parseable Markdown records in the selected location appear in the popover.
- [ ] The popover shows unfinished todos and notes in a compact list.
- [ ] The user can add a note from the popover.
- [ ] The user can add a todo from the popover.
- [ ] The user can mark a todo complete from the popover.
- [ ] Completed todos are visually distinguishable from incomplete todos.
- [ ] The menu bar count updates after add and complete actions.
- [ ] External Markdown changes are reflected after the storage location changes on disk.
- [ ] Malformed Markdown records do not prevent valid records from loading.
- [ ] Storage tests cover reading, writing, completing, malformed records, and externally modified records.
- [ ] Count tests cover active todos, completed todos, reminders without completion, and non-actionable notes.

---

## Phase 3: Reminder Records and Local Notifications

**User stories**: 17, 22, 63, 67, 68, 69, 70

### What to build

Extend the record path to timed reminders. The user can add a reminder with time metadata, see it in the records list, receive a local notification when allowed, and still use the rest of the app when notification permission is denied.

### Acceptance criteria

- [ ] The add flow supports creating a reminder with due or reminder time.
- [ ] Reminder records are stored in Markdown using the same record storage module.
- [ ] Reminders appear in the popover with visible time information.
- [ ] Active reminders contribute to the menu bar count until completed or dismissed according to the record rules.
- [ ] The app requests notification permission only when reminders need notification behavior.
- [ ] Allowed notification permission schedules a local notification for a reminder.
- [ ] Denied notification permission leaves reminders visible in the popover and shows a quiet, compact status.
- [ ] Reminder tests cover parsing, writing, display ordering, count behavior, and notification scheduling decisions.

---

## Phase 4: Global Quick Add

**User stories**: 20, 21, 22, 24, 25, 26, 58, 62, 63

### What to build

Add the global capture path. The user can configure a quick-add hotkey, invoke a compact quick-add panel from anywhere, create a note, todo, or reminder through the same storage path as the popover, and understand when a hotkey cannot be registered.

### Acceptance criteria

- [ ] The Notes/Todos settings tab lets the user configure a global quick-add hotkey.
- [ ] The app registers the configured hotkey while running.
- [ ] Pressing the hotkey opens a compact quick-add panel above other work.
- [ ] The quick-add panel can create a note.
- [ ] The quick-add panel can create a todo.
- [ ] The quick-add panel can create a reminder.
- [ ] Records created from quick add appear in the popover and Markdown storage.
- [ ] Hotkey conflicts or disabled registration states are shown clearly in settings.
- [ ] Quick-add tests verify that popover capture and hotkey capture create equivalent records.
- [ ] Hotkey tests or manual QA cover successful registration, changed shortcut, disabled shortcut, and conflict behavior.

---

## Phase 5: Pomodoro Focus Slice

**User stories**: 33, 34, 35, 36, 37, 38, 39, 50, 51, 52, 57, 61, 62

### What to build

Turn the Pomodoro placeholder into a working focus card. The user can start, pause, resume, and stop a focus session, choose a template, configure templates in settings, hide the Pomodoro card, and keep timer state consistent when the popover closes.

### Acceptance criteria

- [ ] The Pomodoro card shows the current selected template and remaining time.
- [ ] The user can start a Pomodoro session from the popover.
- [ ] The user can pause, resume, and stop a session.
- [ ] Closing and reopening the popover shows the correct current Pomodoro state.
- [ ] The Pomodoro settings tab lets the user enable or hide the card.
- [ ] The Pomodoro settings tab lets the user create, edit, and remove timer templates.
- [ ] Pomodoro templates persist across app restart.
- [ ] Hidden Pomodoro state does not delete existing templates.
- [ ] Pomodoro timer tests use deterministic time and cover start, pause, resume, stop, completion, template switching, and persistence.
- [ ] UI smoke tests or manual QA cover Pomodoro visibility, card order, and compact layout.

---

## Phase 6: Calendar Events Slice

**User stories**: 40, 41, 42, 43, 44, 45, 46, 50, 51, 52, 57, 61, 63

### What to build

Turn the calendar placeholder into a real upcoming-events card. The user can enable calendar integration, grant or deny permission, choose calendar sources, see upcoming events with time and duration, hide the card, and open the full calendar app when needed.

### Acceptance criteria

- [ ] The Calendar settings tab lets the user enable or hide the calendar card.
- [ ] Calendar permission is requested only when the user enables or uses calendar functionality.
- [ ] Denied calendar permission leaves the rest of the popover usable and shows a compact calendar status.
- [ ] Allowed calendar permission loads available calendar sources.
- [ ] The user can select which calendar sources appear in the popover.
- [ ] The calendar card shows upcoming events with start time, title, and duration.
- [ ] The calendar card includes an action to open the full calendar app.
- [ ] Calendar source selection persists across app restart.
- [ ] Hidden calendar state does not delete selected sources.
- [ ] Calendar tests use fake source data for event filtering, source selection, permission states, and display ordering.
- [ ] Manual QA covers real macOS permission prompts and opening the system calendar app.

---

## Phase 7: Unified Settings and App Lifecycle

**User stories**: 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 62, 63

### What to build

Complete the settings and lifecycle behavior now that all major cards exist. The user can manage card order and visibility with real cards, configure launch at login, see automatic updates as disabled by default, and rely on settings persistence across restarts.

### Acceptance criteria

- [ ] General settings show appearance mode, card order, automatic updates, and launch at login.
- [ ] Automatic updates are off by default.
- [ ] Changing the automatic-update preference persists, even if real update delivery remains out of scope.
- [ ] Launch at login can be enabled and disabled.
- [ ] Launch-at-login changes take effect according to macOS behavior.
- [ ] Card ordering works with notes/todos/reminders, Pomodoro, and calendar cards.
- [ ] Feature visibility works with Pomodoro and calendar cards.
- [ ] Settings persistence tests cover all pilot settings.
- [ ] Manual QA covers launch at login and restart behavior.
- [ ] App information includes version/build details and acknowledgements/licenses when third-party dependencies are used.

---

## Phase 8: Pilot Localization, Visual Polish, and Resilience

**User stories**: 5, 6, 7, 8, 9, 10, 11, 12, 57, 58, 59, 60, 61, 62, 63, 66

### What to build

Bring the app to pilot readiness across supported languages and visual modes. The completed popover and settings surfaces should feel compact, native, and close to the reference images while remaining readable in English, German, Korean, and Chinese.

### Acceptance criteria

- [ ] All user-facing pilot strings are localized in English, German, Korean, and Chinese.
- [ ] Unsupported system languages fall back to English.
- [ ] The exact Chinese variant is documented before release.
- [ ] The complete popover remains compact and readable in light mode.
- [ ] The complete popover remains compact and readable in dark mode.
- [ ] Text does not overlap or overflow in the supported pilot languages.
- [ ] The popover scrolls gracefully when content exceeds available height.
- [ ] Keyboard-friendly interactions are available where practical for capture and settings workflows.
- [ ] Error states remain quiet and compact across storage, hotkey, notification, and calendar failures.
- [ ] UI smoke tests or manual screenshots cover the complete popover in light and dark appearances.
- [ ] Localization tests cover supported language selection and fallback behavior.
- [ ] Manual pilot QA covers menu bar count, popover placement, add flows, completion flows, reminders, quick add, Pomodoro, calendar, settings, app information, and restart persistence.
