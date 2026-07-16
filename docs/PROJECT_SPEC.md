# Kindle Smart Dashboard — Project Spec

## 1. Project Goal

Build a small, reliable system that turns a jailbroken Kindle into a low-power e-ink calendar display for Apple Calendar.

The first usable version should:

1. Read calendar data on macOS.
2. Render a 600 × 800 monochrome PNG.
3. Serve the PNG over the local network.
4. Let the Kindle download and display the latest image.

The project prioritizes reliability and simplicity over feature count.

## 2. Target Environment

### Kindle

- Device: Kindle 8th Generation
- Internal device family: KT3
- Firmware: 5.13.7
- Jailbreak: WatchThis
- Hotfix: installed
- Display resolution: 600 × 800
- Orientation: portrait
- Rendering: server-generated PNG
- Network: Wi-Fi

### macOS

- macOS 14 or newer
- Swift 6 target; source remains compatible with the available Swift 5.8 toolchain
- Swift Package Manager
- EventKit for future Apple Calendar access

## 3. V0.1 Scope

V0.1 implements only this data flow:

```text
Mock calendar data
        ↓
Dashboard renderer
        ↓
600 × 800 PNG
        ↓
Local HTTP server
        ↓
GET /dashboard.png
```

V0.1 does not read real Apple Calendar data. Its purpose is to prove that the renderer, PNG output, command-line interface, and HTTP server work correctly.

## 4. V0.1 Features

### 4.1 Dashboard Model

Define simple domain models for:

- dashboard snapshot
- calendar event
- reminder
- footer status

Use mock data during V0.1.

### 4.2 PNG Renderer

The renderer generates:

- PNG format
- 600 × 800 pixels in portrait orientation
- white background with black text and lines
- minimal grayscale only when necessary
- readable Chinese text
- large typography suitable for a 6-inch e-ink display

### 4.3 Initial Layout

The V0.1 image contains:

- date and weekday
- next event
- remaining events today
- todo items
- last updated time

### 4.4 Command-Line Interface

```bash
swift run DashboardCLI render --output ./output/dashboard.png
swift run DashboardCLI serve --host 0.0.0.0 --port 8080
```

### 4.5 HTTP Endpoints

- `GET /dashboard.png` returns the most recently rendered PNG.
- `GET /health` returns a simple successful response.
- Missing output files produce a clear HTTP error instead of crashing.

## 5. Non-Goals for V0.1

Do not implement Apple Calendar, Apple Reminders, weather, stocks, AI summaries, Home Assistant, a message board, Wi-Fi QR codes, Kindle automatic refresh, KUAL extensions, a macOS GUI, cloud services, accounts, remote access, or multiple-device support.

## 6. Technical Principles

- Keep the Kindle simple: download image, display image, sleep.
- Use Swift and native macOS frameworks where practical.
- Do not require Electron, Python, browser screenshots, React, JavaScript rendering, or Docker.
- Keep models, rendering, server, and CLI code separate.
- Make rendering and HTTP behavior testable.
- Avoid premature plugin frameworks or complex dependency injection.

## 7. Package Structure

```text
KindleSmartDashboard/
├── Package.swift
├── Sources/
│   ├── DashboardModels/
│   ├── DashboardRenderer/
│   ├── DashboardServer/
│   └── DashboardCLI/
├── Tests/
│   ├── DashboardModelsTests/
│   ├── DashboardRendererTests/
│   └── DashboardServerTests/
├── output/
├── docs/PROJECT_SPEC.md
├── README.md
└── .gitignore
```

## 8. V0.1 Acceptance Criteria

- `swift build` and `swift test` succeed.
- The render command creates a valid 600 × 800 PNG.
- Chinese mock content displays correctly.
- Empty lists do not crash.
- Long event titles do not overflow the canvas.
- The server starts successfully.
- `/health` succeeds and `/dashboard.png` returns the PNG.
- README contains exact build and run instructions.

## 9. Development Order

Create the package, models, mock data, renderer, render command, HTTP server, tests, verification, and README—in that order. Commit only working code.

## 10. Definition of Done

A feature is complete only when the project builds, tests pass, documented commands work, the PNG has been generated and inspected, and server endpoints have been verified locally.
