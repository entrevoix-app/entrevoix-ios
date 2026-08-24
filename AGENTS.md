# Repository Guidelines

## Project Structure & Module Organization

`Entrevoix/` contains the SwiftUI containing app: composition in
`EntrevoixApp.swift`, screens in `RootView.swift` and `PreferencesView.swift`,
and state in `PreferencesModel.swift`. `Keyboard/` is the custom keyboard
extension and its privacy/entitlement files. Put code shared by the app and
extension in `Shared/`—currently the App Group handoff contract lives in
`Shared/KeyboardHandoff.swift`.

The Xcode project is `Entrevoix.xcodeproj`; its shared `Entrevoix` scheme is
the source of truth for builds and tests. `EntrevoixTests/` holds Swift Testing
unit tests. Shared domain and adapter code comes from the pinned
`EntrevoixShared` Swift package, not from a copied local source tree.

## Build, Test, and Development Commands

Open `Entrevoix.xcodeproj` in Xcode 26+ and select an iOS simulator to run the
app. From the repository root, run the same test command as CI:

```bash
simulator_id="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $2; exit}')"
xcodebuild test -quiet -project Entrevoix.xcodeproj -scheme Entrevoix \
  -destination "id=$simulator_id" CODE_SIGNING_ALLOWED=NO
```

Use `xcodebuild build` with the same project, scheme, destination, and signing
setting for a compile-only check. The workflow in `.github/workflows/ios-tests.yml`
runs tests on pull requests and pushes to `main`.

## Coding Style & Naming Conventions

Use Swift 6, four-space indentation, and Xcode’s standard formatting. Prefer
small SwiftUI views and `@Observable` models; the project defaults Swift code to
`@MainActor`, so make cross-actor boundaries explicit. Use `UpperCamelCase` for
types, `lowerCamelCase` for members, and name files after their main type. Keep
App Group identifiers, entitlement values, and handoff keys stable unless both
targets are updated together.

## Testing Guidelines

Write unit tests with Swift Testing (`import Testing`), `@Suite`, `@Test`, and
`#expect`. Name tests after observable behavior, e.g. `resetRemovesPreferencesButKeepsKeys`.
Add coverage for new model behavior and shared app/keyboard contracts; avoid
network and real Keychain access by using protocol spies.

## Commit & Pull Request Guidelines

Use conventional commits consistent with history: `feat(keyboard): ...`,
`test(ios): ...`, or `chore(agents): ...`. Keep each commit independently
buildable. PRs target `main`, describe context, changes, and the exact test
command run; link an issue when one exists. Include screenshots for visible UI
changes and call out platform-specific limitations or follow-up work.
