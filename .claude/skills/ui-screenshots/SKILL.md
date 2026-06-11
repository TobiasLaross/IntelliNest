---
name: ui-screenshots
description: >-
  Capture screenshots of an IntelliNest SwiftUI UI change under several data variations (empty /
  loading / full / long-text / grouped / error), so the user can eyeball the result instead of
  trusting a green build. Use this WHENEVER you add or modify anything a user can see in the app —
  a new view or sheet, a restyle, a layout or spacing tweak, a Swedish copy change, an empty/error/
  loading state, a list row, a dashboard button — even if the user only said "make X look like Y"
  and never mentioned screenshots. Build/test green is not enough: the type-checker can't see
  padding, ordering, truncation, contrast, or theme regressions. Primary mechanism is rendering the
  real SwiftUI views to PNG with sample data via ImageRenderer (no Home Assistant needed); an
  optional live-simulator path captures real HA data when local secrets exist. Do NOT use it for
  service-layer-only, test-only, refactor, or doc changes with no visible result.
---

# UI screenshots with data variations (IntelliNest)

Goal: turn "I changed a screen" into a handful of screenshots — the same screen under different
**data** (empty vs full, short vs long, one speaker vs grouped) plus a **before** image when you
restyled something that already existed. The user reviews variations, not a single happy-path shot,
because that is where layout bugs hide: the Swedish label that truncates at 18 characters, the
empty state nobody styled, the speaker list that breaks when all six are grouped.

IntelliNest is a SwiftUI MVVM app that talks to a live Home Assistant instance over REST/WebSocket.
There is **no backend to seed** and (on most machines) **no local secrets** — so the default,
reliable way to screenshot is to render the real views to PNG with constructed sample state, the
same technique used in the test target. A live-simulator path exists for real HA data, but it is
heavier and needs secrets + LAN access.

## This is a bug hunt, not a photo op

Rendering the real views catches what build-green and unit tests **cannot**: unit tests assert
view-model state, not pixels, so a truncated title, a dark-on-dark label, an empty state nobody
wired, a control with no accessibility label all sail through green and only show up on screen.
Drive like an adversary, not a tourist:

- **Shoot the edge states, not just the happy path.** The empty speaker picker (nothing playing),
  the loading state (`state == "Loading"`), the error banner, a 30-character Swedish room name, all
  six speakers grouped, an unavailable speaker filtered out. These are where bugs live and they are
  nearly free to render once the harness is up.
- **When a screen looks wrong, STOP and investigate.** A blank list, a value that won't format, a
  control that overlaps: each is a lead. Read the view, the view-model state mapping, the entity
  decoder. Root-cause it.
- **Fix what you find, then re-render.** A real bug → fix it, log it in the feature's `design.md`
  (if there is a feature folder), rebuild, re-shoot to confirm. A render run that finds and fixes a
  bug is worth far more than tidy images of a broken screen.
- **Surface every finding to the user**, even ones you can't fix cleanly.

It's also a **UX review**, not only a correctness check. A screen can be functionally correct and
still be bad: a title truncated to "Vardagsrumm…", a tap target the size of a grain of rice, an
empty state that explains nothing. Judge every screen the way the *user* will hitting it cold —
"can I read this, find this, tap this, understand what to do next?" See step 6; the UX pass is
mandatory.

## Default mechanism: render the real views to PNG (ImageRenderer)

`ImageRenderer` (iOS 16+) renders a SwiftUI view to a `UIImage` with no window, no simulator
driving, and no Home Assistant — you construct the view-model state in code and render. This is
deterministic, fast, and needs no secrets. It runs inside the test target so it can reach the app's
internal views via `@testable import IntelliNest`.

### 1. Add a temporary render method to an existing test file

Do **not** create a new test file — the Xcode project uses manual `pbxproj` file references, so a
new file needs project registration. Instead append a method to an existing `IntelliNestTests/
<Feature>Tests.swift` (e.g. `MusicViewModelTests.swift`) and add `import SwiftUI` / `import UIKit`
at the top. Put the method in an `extension` of the test class if the class body is near the
SwiftLint `type_body_length` limit (extensions are not counted).

Render helper and a worked example (adapt the view + state to your change):

```swift
func write(_ view: some View, name: String) {
    let dir = "/tmp/intellinest-shots/<short-desc>"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let renderer = ImageRenderer(content: view
        .frame(width: 393)                 // iPhone logical width; omit height for intrinsic
        .foregroundStyle(.white)           // the app sets white text at the screen level
        .padding()
        .backgroundModifier())             // the app's gradient background
    renderer.scale = 3
    if let data = renderer.uiImage?.pngData() {
        try? data.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
}
```

Construct view-model state directly for each variation. Entities are `var` structs, so mutate after
init: `var speaker = MediaPlayerEntity(entityId: .mediaPlayerKitchen, state: "playing",
friendlyName: "Kitchen"); speaker.volumeLevel = 0.4`. For state that only `reload()` produces, drive
it through `URLProtocolStub` exactly like the existing tests (stub the entity GET, `await
viewModel.reload()`), then render.

### 2. Run only the render method, collect the PNGs

```sh
xcodebuild test \
  -project IntelliNest.xcodeproj -scheme "IntelliNest-github" -testPlan "IntelliNest-github" \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -configuration "Github actions" \
  -only-testing:IntelliNestTests/<Class>/<renderMethod> \
  CODE_SIGNING_ALLOWED=NO | xcbeautify
ls /tmp/intellinest-shots/<short-desc>/
```

Use an installed simulator — `iPhone 17` is current; run `xcrun simctl list devices available` if it
differs. The render runs offline; no HA, no network.

### 3. Design 2–4 variations

List the data conditions that change how *this specific screen* lays out, and render one image each:

- **Volume** — empty / one / many (no speakers playing → picker; one active; all six grouped).
- **Length** — short vs long Swedish strings that test truncation/wrapping (a 30-char room name, a
  long track + artist).
- **State** — loading (`"Loading"`), idle, playing, paused, unavailable (filtered out), error banner
  shown, shuffle/repeat on.
- **Before/after** — if you restyled an existing screen, render the same variation on the
  merge-base (`git stash` or a worktree at `origin/main`) and pair them.

### 4. ImageRenderer caveats — know what it can't draw

`ImageRenderer` rasterizes SwiftUI, but **UIKit-backed controls don't render**:

- **Native `Slider`** renders as a centered "🚫" glyph with a full track, independent of value — it
  is NOT the real knob. IntelliNest's volume control is a custom `FillSlider` (in `NowPlayingView`)
  that renders correctly *because* it's a pure SwiftUI view; prefer custom fill controls over native
  `Slider` and they screenshot faithfully.
- **`AsyncImage`** shows its placeholder (no network in the render) — album art / camera snapshots
  appear as the `music.note` / placeholder, not the real image. Note it in the caption.
- **`Map`, `VideoPlayer`, web views** won't render.

When you render a subview in isolation, wrap it with `.foregroundStyle(.white)` and
`.backgroundModifier()` so colours match the app (the screen-level view sets these). If a native
control matters to the shot, fall back to the live-simulator path below.

## Optional: live-simulator screenshots with real HA data

Use this only when the screen needs real Home Assistant data or a native control the renderer can't
draw, AND `IntelliNest-Info.xcconfig` (real secrets) exists in the repo AND the Mac is on the home
LAN. It is heavier (navigation must be driven) and touches the live home — **read-only only**.

```sh
# build the app (Debug uses the real xcconfig) and install on a booted iPhone 17 sim
xcodebuild -project IntelliNest.xcodeproj -scheme IntelliNest -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  -derivedDataPath /tmp/intellinest-dd build
xcrun simctl install booted \
  "$(/usr/bin/find /tmp/intellinest-dd/Build/Products -name 'IntelliNest.app' -maxdepth 3 | head -1)"
xcrun simctl launch booted <bundle-id>
xcrun simctl io booted screenshot /tmp/intellinest-shots/<desc>/home.png
```

`simctl` cannot tap, so navigation to a specific screen needs `idb` (`brew install
facebook/fb/idb-companion` + `pip install fb-idb`) driving by visible label, or you hand the user a
build to drive. Because there is no UI-test target, the render-to-PNG path above is usually the
faster, more reliable choice. **Never** drive a state-changing HA action from a screenshot run —
no locks, no `play_media`, no charging toggles, no heater changes. State reads only.

## 5. Deliver as one grouped batch

Send every shot in a **single** `SendUserFile` call (status `proactive`), `files` ordered the way the
user should read them, with one caption naming the states in order ("1 empty · 2 single active · 3
all grouped · 4 long title"). One multi-file call groups them into one message instead of a
scattered stream. Mention any ImageRenderer artifact in the caption (e.g. album art is a placeholder
because there's no network in the render).

## 6. UX review — mandatory before you deliver any shot

Not optional polish, not "does it match the spec". Run every shot through this before sending.

### 6a. Per-screen defect scan — these are DEFECTS, fix them, do not ask

Look at each screen as a user seeing it cold. If any is present, fix it in code, re-render, fold into
the same change — do **not** list it as a suggestion or ship around it:

- **Truncation / clipping** — any user-meaningful text cut off (`…`, hard clip). A room name, track
  title, or value the user came to read must be fully visible. Restructure (own line, wrap, reflow)
  until it is. (This skill exists partly because a home-stats block once collapsed to one truncated
  line — that's a defect, not a "your call".)
- **Contrast on the gradient** — the app draws white-ish text on a dark blue→green gradient. Watch
  for low-contrast text, a colour that disappears against the fill, an accent that's hard to see.
- **Swedish copy** — labels, empty states, and units in correct Swedish (the app is Swedish
  throughout: "Musik", "Välj högtalare", "Inga resultat"). Flag English leaks and bad pluralization.
- **Missing accessibility** — a new interactive control without an `.accessibilityLabel` (VoiceOver),
  or a container that collapses its children's labels.
- **Tap targets** — an interactive element too small or cramped to hit reliably.
- **Broken/empty/loading states** — an empty, loading, or error state that is unstyled or unexplained.
- **Overflow / overlap / misalignment** — elements colliding, spilling, or visibly off-grid.

**No-rationalization rule.** "It technically renders", "it fits at this width", "it truncates
gracefully", "the data is correct" do **not** downgrade a visible defect to acceptable. If a user
would say "that's broken" or "I can't read that", fix it.

### 6b. UX-improvement lens — make the screen genuinely better

For each screen, ask what the user is trying to accomplish and whether the design helps:

- **Hierarchy** — is the most important thing the most prominent? Is the primary action obvious?
- **Scannability** — can the user find what they need at a glance? Are related things grouped?
- **Clarity** — plain Swedish that says what to do next; no dead-end empty states.
- **Consistency** — does this screen do rows/buttons/headers the same way the rest of the app does
  (e.g. `NavigationButtonView`, `ServiceButtonView`, the dashboard's gradient buttons)?
- **First-time vs returning** — does a no-data state make sense, and does a full/grouped state stay
  clean?

Small, clearly-better, in-scope fix → just do it and re-render. Subjective or larger change →
suggest, don't act; list it alongside the screenshots and let the user decide.

When unsure which side of the 6a/6b line something is on, treat it as a defect and fix it.

## 7. Clean up, then ask — and state what you reviewed

- **Revert the temporary render method** and the `import SwiftUI`/`UIKit` additions — never commit
  the render test or the PNGs. `git checkout -- IntelliNestTests/<Class>Tests.swift` and
  `rm -rf /tmp/intellinest-shots/<short-desc>` after delivering.
- After delivering, ask the user explicitly — "Does the empty state look right?", not "I'm done." In
  the same message say what UX review you ran: which 6a defects you found and fixed (with a re-shot
  image) and which 6b improvements you're suggesting vs. applied.

## Hard rules

- **Default to render-to-PNG.** It needs no secrets, no HA, no simulator driving, and renders the
  real views — use it unless a native control or real data genuinely requires the live path.
- **Never commit the render test or the PNGs.** Revert the temp method and imports when done.
- **Live path is read-only.** Never trigger a state-changing HA action (lock, `play_media`, charging,
  heater) from a screenshot run — entity-state reads only.
- **Always run the step-6 UX review** on every shot before delivering, and **fix** every 6a defect
  (truncation, clipping, contrast, missing a11y, broken/empty state, overflow) in-flight — never
  deliver one as a "your call". "It technically renders / fits / truncates gracefully" is not an
  exception.
- Use an installed simulator (`iPhone 17` currently) and the `Github actions` config with
  `CODE_SIGNING_ALLOWED=NO` for render runs, matching the repo's CI.
