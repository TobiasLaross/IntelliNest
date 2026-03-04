# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

**Run all tests (local):**
```bash
xcodebuild test \
  -project IntelliNest.xcodeproj \
  -scheme "IntelliNest-github" \
  -testPlan "IntelliNest-github" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  -configuration "Github actions" \
  CODE_SIGNING_ALLOWED=NO | xcbeautify
```

**Run a single test class:**
```bash
xcodebuild test \
  -project IntelliNest.xcodeproj \
  -scheme "IntelliNest-github" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  -configuration "Github actions" \
  -only-testing:IntelliNestTests/HomeViewModelTests \
  CODE_SIGNING_ALLOWED=NO | xcbeautify
```

Install `xcbeautify` with `brew install xcbeautify` if not present.

**Local development** requires `IntelliNest-Info.xcconfig` (not committed). Copy `Github-Info.xcconfig` and fill in real secrets.

## Architecture

### MVVM + Navigator

The app uses MVVM with SwiftUI. `Navigator` (in `Navigation/`) is the central coordinator — a `@StateObject` owned by `AppMain`. It:
- Lazily initializes all ViewModels
- Owns the `NavigationPath` for the SwiftUI `NavigationStack`
- Runs a continuous reload loop (every 5 seconds) to keep entity state current
- Manages the error banner state shown across all views
- Triggers geofence-driven lock/unlock actions

`AppMain.swift` detects test mode via environment variables and skips full initialization when running tests.

### ViewModels

All ViewModels are `@MainActor ObservableObject` classes. Key ones:
- `HomeViewModel` — controls locks, lights, appliances, Yale API integration
- `ElectricityViewModel` — power consumption, NordPool pricing, solar/grid data
- `HeatersViewModel` — thermostat mode/fan/temperature
- `LynkViewModel` — EV car climate and charging
- `RoborockViewModel` — vacuum control and room targeting

ViewModels receive `RestAPIService`, `YaleApiService`, and `URLCreator` via constructor injection. Navigation is decoupled via closure callbacks passed at init.

### Service Layer

- **`RestAPIService`** — HTTP calls to Home Assistant REST API (`/api/states/{entityId}`, `/api/services/{domain}/{action}`). Inherits from `URLRequestBuilder`.
- **`YaleApiService`** — Yale lock API with Keychain-stored JWT tokens, auto-refresh logic.
- **`URLCreator`** — Checks the current SSID against the configured home SSID to decide between internal URL (local LAN) and external URL (DuckDNS). Updates `RestAPIService.internalUrl`/`externalUrl` dynamically.

Most real-time entity updates use WebSocket (`HAWebSocketService`) rather than REST polling.

### Models

`EntityProtocol` is the base for all Home Assistant entities. It carries `state`, `entityId`, and timestamps. Concrete types (`LightEntity`, `LockEntity`, `HeaterEntity`, etc.) add domain-specific decoded properties.

All entity IDs are declared in the `EntityId` enum; all HA domains in `Domain`; all service actions in `Action`. Always add new IDs there rather than using raw strings.

### Configuration

Secrets are injected via xcconfig variables at build time (accessed as `Bundle.main.infoDictionary` values). `Github-Info.xcconfig` contains placeholder values safe to commit. Never commit `IntelliNest-Info.xcconfig`.

## Pre-commit: SwiftFormat & SwiftLint

Run both tools on changed Swift files before every commit, matching what Xcode does in its build phases.

**SwiftFormat** (bundled binary, same flags as the Xcode build phase):
```bash
BuildTools/SwiftFormat/swiftformat . --indent 4
```

**SwiftLint** (Homebrew install, same config as the Xcode build phase):
```bash
swiftlint --config .swiftlint
```

Fix all SwiftLint errors before committing. Warnings are acceptable but errors are not. The config (`.swiftlint`) sets a warning threshold at 140 chars and an error threshold at 160 chars per line.

## Commit Messages

Based on the project history, follow this style:

- **Past tense**, capitalised first word, no trailing period — e.g. `Added garden waste to upcoming events`, `Fixed spot prices`, `Improved websocket handling by unsubscribing`
- **Short and specific** — describe what changed, not why. One line is the norm; no body needed.
- Common leading verbs: `Added`, `Fixed`, `Improved`, `Removed`, `Updated`, `Renamed`, `Refactored`, `Increased`
- PR numbers (`(#104)`) are appended automatically by GitHub on merge — do not add them manually.

Examples from history:
```
Added storage lock
Fixed ui issues on electricity
Improved handling of geofence tracking
Removed websocket
Refactored all files using swiftformat swift version 5.10
```

### Testing

Tests live in `IntelliNestTests/`. The pattern:
1. `URLProtocolStub` intercepts URLSession requests and returns pre-configured mock responses.
2. `TestHelpers.swift` provides factory helpers for common stub setups.
3. ViewModels are instantiated with a stubbed `URLSession` passed through `RestAPIService`.

Tests validate both initial state and post-`reload()` state. Use `await Task.yield()` or short `Task.sleep` calls only when async work must settle — check existing tests for the established pattern before adding new ones.
