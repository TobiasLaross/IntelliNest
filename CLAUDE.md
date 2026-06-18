# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

**Run all tests (local):**
```bash
xcodebuild test \
  -project IntelliNest.xcodeproj \
  -scheme "IntelliNest-github" \
  -testPlan "IntelliNest-github" \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -configuration "Github actions" \
  CODE_SIGNING_ALLOWED=NO | xcbeautify
```

**Run a single test class:**
```bash
xcodebuild test \
  -project IntelliNest.xcodeproj \
  -scheme "IntelliNest-github" \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -configuration "Github actions" \
  -only-testing:IntelliNestTests/HomeViewModelTests \
  CODE_SIGNING_ALLOWED=NO | xcbeautify
```

Install `xcbeautify` with `brew install xcbeautify` if not present.

**Local development** requires `IntelliNest-Info.xcconfig` (not committed). Copy `Github-Info.xcconfig` and fill in real secrets.

## Running on Tobias's iPhone (physical device)

Use this to verify changes that a screenshot can't prove — animation speed, gestures, live HA data.
Mirrors the `lilaDevice` zsh helper (`~/dotfiles/zsh/config/functions.zsh`), adapted for IntelliNest.

**Device IDs** (Tobias's iPhone 17 Pro):
- Build-destination hardware UDID: `00008150-00124D500108401C`
- CoreDevice UUID (for `devicectl` install/launch): `911101B1-0BE6-5943-A15E-E2F78F289A00`
- App bundle id: `se.laross.IntelliNest`

**One-time prerequisites (a human must do these in Xcode — they can't be scripted):**
1. **Apple ID account.** Xcode → Settings → Accounts → add the Apple ID for team `2LLC328P4S`.
   Without it, automatic signing fails with *"No Accounts: Add a new account in Accounts settings"*
   because there is no `se.laross.IntelliNest` provisioning profile on disk and minting one needs
   the account. (`lilaDevice` only works because the `se.laross.lila` profiles already exist locally.)
2. **Generate the profiles once.** Open `IntelliNest.xcodeproj` in Xcode with the device connected and
   build to it once, so Xcode creates the `se.laross.IntelliNest` and `se.laross.IntelliNest.IntelliWidget`
   profiles under `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`. After that the CLI build works.
3. **Secrets file.** `IntelliNest-Info.xcconfig` must exist at the repo root. If missing, reconstruct a
   minimal one — enough to reach HA on the LAN and show real data — from the local token:
   ```bash
   TOKEN=$(cat ~/.config/intellinest/ha_token)
   cat > IntelliNest-Info.xcconfig <<EOF
   EXTERNAL_URL = 192.168.1.205:8123/
   LOCAL_SSID = None
   SECRET_HASS_TOKEN = $TOKEN
   SECRET_HASS_TOKEN_SARAH = $TOKEN
   SECRET_YALE_API_KEY = abc
   SECRET_YALE_API_URL = abc.com
   SPOTIFY_CLIENT_ID = abc
   MUSIC_ASSISTANT = abc
   EOF
   ```
   `LOCAL_SSID = None` makes `URLCreator` skip the SSID check and race the hardcoded LAN address
   `http://192.168.1.205:8123/` (in `GlobalConstants`), which wins when the device is on home wifi.
   Yale/Spotify are placeholders; only electricity/HA features work. The file is git-ignored.

**Build, install, launch** (run unsandboxed — signing needs keychain access; do NOT pass
`-derivedDataPath` inside the repo or the SwiftLint build phase lints the SwiftPM package checkouts):
```bash
xcodebuild -project IntelliNest.xcodeproj -scheme IntelliNest -configuration Debug \
  -destination "id=00008150-00124D500108401C" -allowProvisioningUpdates build

APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/IntelliNest-*/Build/Products/Debug-iphoneos/IntelliNest.app | head -1)
xcrun devicectl device install app --device 911101B1-0BE6-5943-A15E-E2F78F289A00 "$APP"
xcrun devicectl device process launch --device 911101B1-0BE6-5943-A15E-E2F78F289A00 se.laross.IntelliNest
```

**Driving the UI** (the device shows real prompts on first launch): tap with `idb ui tap <x> <y>`
(point coords; `idb describe --udid <coredevice-uuid>` gives `width_points`). On first launch expect, in
order: location prompt → notifications prompt → "Välj användare" (pick **Tobias**). The electricity
dashboard is the **powergrid** button in the home grid.

If device signing can't be set up, fall back to the **iOS Simulator** (no signing needed): build the
`IntelliNest` scheme with `-destination "platform=iOS Simulator,name=iPhone 17,OS=latest"
CODE_SIGNING_ALLOWED=NO`, install with `simctl`, and drive it with the same `idb` taps. The Mac is on
the LAN so it reaches HA with the same reconstructed xcconfig.

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

ViewModels receive `RestAPIService`, `YaleApiService`, and `URLCreator` via constructor injection. Navigation is decoupled via closure callbacks passed at init.

### Service Layer

- **`RestAPIService`** — HTTP calls to Home Assistant REST API (`/api/states/{entityId}`, `/api/services/{domain}/{action}`). Inherits from `URLRequestBuilder`.
- **`YaleApiService`** — Yale lock API with Keychain-stored JWT tokens, auto-refresh logic.
- **`URLCreator`** — Checks the current SSID against the configured home SSID to decide between internal URL (local LAN) and external URL (DuckDNS). Updates `RestAPIService.internalUrl`/`externalUrl` dynamically.

### State freshness

There is no WebSocket layer (it was removed — the README's "uses WebSocket" claim is stale). All entity state is
kept current by the `Navigator`'s continuous 5-second loop, which calls `reload()` on every ViewModel. ViewModels and
entities conform to `Reloadable` (`Model/Reloadable.swift`); a `reload()` re-fetches state via `RestAPIService` (GET
`/api/states/{entityId}`) and republishes. A few services that return a body (e.g. Music Assistant search) use a
dedicated `return_response` request path rather than the fire-and-forget POST used for most service calls.

### Models

`EntityProtocol` is the base for all Home Assistant entities. It carries `state`, `entityId`, and timestamps. Concrete types (`LightEntity`, `LockEntity`, `HeaterEntity`, etc.) add domain-specific decoded properties.

All entity IDs are declared in the `EntityId` enum; all HA domains in `Domain`; all service actions in `Action`. Always add new IDs there rather than using raw strings.

### Configuration

Secrets are injected via xcconfig variables at build time (accessed as `Bundle.main.infoDictionary` values). `Github-Info.xcconfig` contains placeholder values safe to commit. Never commit `IntelliNest-Info.xcconfig`.

### Adding a new screen / device

A new device dashboard touches a fixed set of files in this order — follow an existing domain (e.g. `lights`,
`heaters`) as the template:

1. Add a `Destination` case with its Swedish `title` (`Navigation/Destination.swift`).
2. Wire it into `Navigator` — a lazily-created `@MainActor ObservableObject` ViewModel, a `showXAction` closure, and
   the `navigationDestination` switch — plus the parallel switch in `NavigatorHelpers`. Add the ViewModel to the
   reload loop so it stays current.
3. Add the new HA contract to the enums first: `EntityId`, `Domain`, `Action` (and `JSONKey` for new attribute keys).
   Never use raw entity-id or service strings in feature code.
4. Add an `EntityProtocol` model that decodes the entity's `attributes`.
5. Build the ViewModel (constructor-injected `RestAPIService`/`URLCreator`, navigation via injected closures, a
   `reload()` that refreshes state) and its View under `Views/<Domain>/`.
6. Surface the entry point — typically a `NavigationButtonView` in `HomeView`'s button grid wired to the new
   `showXAction` (which is threaded through `HomeViewModel`'s init and its PreviewProvider).

The Xcode project uses **manual** `pbxproj` file references (not Xcode 16 file-system-synchronized groups), so new
`.swift` files must be added to the `IntelliNest` target (and tests to `IntelliNestTests`) explicitly — via Xcode or
a hand-edit of `project.pbxproj` — or they will not compile.

## Pre-commit: SwiftFormat & SwiftLint

Run both tools on changed Swift files before every commit, matching what Xcode does in its build phases.

**SwiftFormat** (bundled binary, same flags as the Xcode build phase):
```bash
BuildTools/SwiftFormat/swiftformat . --indent 4
```

**SwiftLint** (Homebrew install, same config and `--strict` as the Xcode build phase and CI):
```bash
swiftlint --strict --config .swiftlint
```

SwiftLint runs with `--strict` in both the Xcode build phase and CI, so **every warning is treated as an
error** and fails the build. Fix all violations before committing — there is no acceptable-warning tier.
The config (`.swiftlint`) sets a line-length warning at 140 chars and error at 160; `file_length` uses the
default 400-line limit, so split files that grow past it rather than letting the warning ride.

## Screenshots for UI changes

Any change that affects what a user sees on screen — a new view or sheet, a restyle, a layout or
spacing tweak, a Swedish copy change, an empty/error/loading state, a list row, a dashboard button —
must be verified with screenshots, not just a green build. The type-checker can't see padding,
ordering, truncation, contrast, or theme regressions.

Use the `ui-screenshots` skill: it renders the real SwiftUI views to PNG with sample data via
`ImageRenderer` (no Home Assistant needed), with an optional live-simulator path that uses real HA
data when local secrets exist. Capture one screenshot per distinct state worth verifying (collapsed
vs. expanded, empty vs. populated, success vs. error, long text).

Send screenshots **in flight, proactively** via `SendUserFile` (status: `proactive`) the moment a
meaningful state is reachable — don't wait until the end; a short caption is enough. After PRs are
open, ask explicitly whether the screenshots look right ("Looks good?", not "I'm done."). This does
not apply to service-layer-only, test-only, refactor, or doc changes with no visible result.

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
