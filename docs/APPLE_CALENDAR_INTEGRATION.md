# Apple Calendar Integration Specification

Implementation status: implemented and locally smoke-tested on 2026-07-16. The build and 17 automated tests passed under Xcode 15.2; the signed helper obtained Calendar permission and rendered a real 600 × 800 grayscale PNG. Mock rendering and the HTTP test suite also passed.

## 1. Purpose

V0.2 replaces the mock calendar events with read-only events from Apple Calendar on macOS while preserving the existing rendering, PNG, CLI, and HTTP behavior.

The integration must remain local, small, and testable. Calendar data must never leave the Mac except as text rendered into the dashboard PNG served on the local network.

## 2. Prerequisite

Do not begin implementation until the existing V0.1 package passes:

```bash
swift build
swift test
swift run DashboardCLI render --output ./output/dashboard.png
```

The supported development setup for the current Intel Mac is:

- macOS Ventura 13.5 or newer
- Xcode 15.2 with Swift 5.9
- macOS 13 deployment target, with availability handling for macOS 14 APIs

The project uses Xcode 15.2. Select it with:

```bash
sudo xcode-select --switch /Applications/Xcode-15.2.app/Contents/Developer
sudo xcodebuild -license accept
```

## 3. V0.2 Scope

V0.2 implements only this data flow:

```text
Apple Calendar / EventKit
        ↓
Calendar provider
        ↓
Dashboard CalendarEvent models
        ↓
Existing renderer
        ↓
600 × 800 PNG
```

V0.2 must:

- request permission to read calendar events;
- read events that overlap the current local calendar day;
- map EventKit objects into project-owned models;
- render the real events through the existing renderer;
- retain mock data as an explicit development and test mode;
- fail with a clear message instead of crashing or silently showing stale data.

## 4. Non-Goals

Do not add the following in V0.2:

- creating, editing, or deleting events;
- Apple Reminders;
- calendar selection UI;
- a macOS menu bar or graphical application;
- background scheduling or a LaunchAgent;
- Kindle automatic refresh;
- cloud synchronization owned by this project;
- Google Calendar or Microsoft Graph APIs;
- caching raw calendar event data to disk.

## 5. Architecture

Add one module:

```text
Sources/
└── DashboardCalendar/
    ├── CalendarProviding.swift
    ├── EventKitCalendarProvider.swift
    └── CalendarAccess.swift
```

`DashboardCalendar` may depend on `DashboardModels` and EventKit. `DashboardModels`, `DashboardRenderer`, and `DashboardServer` must not import EventKit.

Use a narrow provider boundary:

```swift
public protocol CalendarProviding {
    func events(in interval: DateInterval) async throws -> [CalendarEvent]
}
```

The CLI chooses either:

- `EventKitCalendarProvider` for real calendar data; or
- `MockCalendarProvider` for deterministic development and tests.

Do not add a general dependency-injection framework.

## 6. Authorization

The project needs read access, so write-only authorization is insufficient.

Authorization behavior:

| Status | Required behavior |
| --- | --- |
| Not determined | Request full event access once. |
| Full access / authorized | Continue with the query. |
| Write only | Report that read access is required. |
| Denied | Explain how to enable Calendar access in System Settings. |
| Restricted | Return a clear unsupported-access error. |

When built with Xcode 15:

- On macOS 14 or newer, use `requestFullAccessToEvents()` and treat `.fullAccess` as readable.
- On macOS 13, use the availability-checked legacy `requestAccess(to: .event)` path and treat `.authorized` as readable.

The executable must provide both permission descriptions needed by the supported OS range:

- `NSCalendarsFullAccessUsageDescription`
- `NSCalendarsUsageDescription`

Suggested user-facing text:

> Kindle Smart Dashboard reads today's calendar events locally to render your e-ink dashboard. Calendar data is not uploaded.

### 6.1 Permission spike

Before implementing the full provider, add and manually verify a minimal authorization command:

```bash
swift run DashboardCLI calendar-status
swift run DashboardCLI calendar-authorize
```

The permission spike confirmed that a bare Swift Package Manager executable remains `notDetermined` and macOS returns `false` without presenting a TCC prompt. V0.2 therefore packages the same `DashboardCLI` binary in a locally signed, non-UI App Bundle solely to establish a stable TCC identity. This wrapper must not add windows, menus, background scheduling, or other GUI behavior.

## 7. Query Rules

Use `Calendar.autoupdatingCurrent` and its current time zone.

For a render date `now`:

```swift
let start = calendar.startOfDay(for: now)
let end = calendar.date(byAdding: .day, value: 1, to: start)!
let interval = DateInterval(start: start, end: end)
```

Create the EventKit predicate with the start and end of this half-open interval. Events that overlap the interval must be included, including:

- all-day events;
- events that began before midnight and end today;
- events that begin today and end after midnight;
- occurrences of recurring events returned by EventKit.

Query all event calendars in V0.2. Calendar allowlists and configuration belong to a later version.

EventKit does not guarantee chronological results. Sort mapped events deterministically:

1. all-day events first;
2. start date;
3. end date;
4. localized title.

## 8. Model Mapping

Extend the project-owned `CalendarEvent` only as required:

```swift
public struct CalendarEvent {
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let isAllDay: Bool
}
```

Mapping rules:

| EventKit value | Dashboard value |
| --- | --- |
| `title` | Trim whitespace; use `未命名日程` when empty. |
| `startDate` | Preserve the absolute date. |
| `endDate` | Preserve the absolute date; reject invalid events ending before they start. |
| `location` | Trim whitespace; map an empty value to `nil`. |
| `isAllDay` | Preserve directly. |

Do not retain `EKEvent` instances outside the provider. Do not expose EventKit types to other modules. Event identifiers are not required in V0.2 because the dashboard is read-only and renders a fresh snapshot.

## 9. Rendering Rules

- All-day events display `全天` instead of `00:00–00:00`.
- An event already in progress remains eligible as the next event until its end time.
- Finished events are not shown in the “later” list.
- Cross-day timed events display their local start and end times without adding a second layout row.
- Existing truncation rules continue to protect the canvas from long titles and locations.
- No-event output remains a successful dashboard state.

## 10. CLI Behavior

Retain the existing commands and add a data-source option:

```bash
swift run DashboardCLI render --source calendar --output ./output/dashboard.png
swift run DashboardCLI render --source mock --output ./output/dashboard.png
```

Rules:

- `calendar` becomes the default only after permission and integration acceptance tests pass.
- `mock` remains available and deterministic.
- `serve` continues serving the last successfully rendered PNG and never requests Calendar permission.
- A failed calendar read must not overwrite a previously valid PNG.
- CLI errors must distinguish denied permission, restricted access, query failure, and invalid event data.

## 11. Privacy and Security

- Calendar access is read-only.
- Raw titles, locations, identifiers, and account information must not be logged.
- Raw calendar data must not be written to disk.
- No analytics or network request may contain calendar data.
- The only persisted result is the rendered dashboard PNG.
- README must explain that anyone on the permitted local network who can reach the HTTP endpoint can view the rendered calendar text.

## 12. Testing

### Unit tests

- authorization status maps to the correct project error or action;
- query interval respects local midnight and daylight-saving transitions;
- EventKit mapping trims strings and handles missing titles;
- all-day, cross-day, recurring occurrence, empty, and invalid events are handled;
- sorting is deterministic;
- provider errors do not overwrite an existing PNG;
- the renderer formats all-day events correctly.

Tests must use provider fakes and project-owned fixture values. Unit tests must not request real Calendar permission.

### Manual tests

Use a dedicated local test calendar containing:

- one all-day event;
- one current event;
- one future event;
- one recurring event occurrence;
- one cross-midnight event;
- one long Chinese title and location.

Verify permission granted, denied, and subsequently enabled in System Settings. Inspect the generated PNG after each scenario.

## 13. Implementation Order

1. Restore a working Xcode 15.2 toolchain and pass V0.1 tests.
2. Perform the command-line Calendar permission spike.
3. Add `isAllDay` to the domain model and renderer.
4. Add `DashboardCalendar` and its provider protocol.
5. Implement EventKit authorization and querying.
6. Add `--source mock|calendar` without changing `serve`.
7. Add unit tests and manual permission fixtures.
8. Run build, tests, render inspection, and HTTP regression checks.
9. Update README and commit only working code.

## 14. Acceptance Criteria

V0.2 is complete when:

- `swift build` and `swift test` pass under Xcode 15.2;
- Calendar permission is requested with a clear privacy description;
- denied and restricted access produce actionable errors;
- today's real Apple Calendar events render into a 600 × 800 PNG;
- all-day, ongoing, future, recurring, and cross-day events behave as specified;
- mock mode remains functional and deterministic;
- Calendar failures do not destroy the last valid PNG;
- `/health` and `/dashboard.png` retain their V0.1 behavior;
- no raw calendar data is persisted or transmitted.

## 15. Official References

- [Apple: EKEventStore](https://developer.apple.com/documentation/eventkit/ekeventstore)
- [Apple: Accessing Calendar using EventKit and EventKitUI](https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui)
- [Apple: Retrieving events and reminders](https://developer.apple.com/documentation/eventkit/retrieving-events-and-reminders)
- [Apple: EKAuthorizationStatus](https://developer.apple.com/documentation/eventkit/ekauthorizationstatus)
- [Apple: Xcode version compatibility](https://developer.apple.com/support/xcode/)
