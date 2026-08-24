---
name: ios-best-practices
description: >-
  Use when implementing accessibility (VoiceOver labels/hints/values,
  accessibilityElement grouping, Dynamic Type, Reduce Motion/Transparency),
  privacy (Info.plist usage-description keys, App Tracking Transparency,
  PrivacyInfo.xcprivacy privacy manifest, required-reason APIs), performance
  (Instruments Time Profiler, main-thread blocking, List performance, image
  caching, launch time), testing (XCTest/Swift Testing UI tests, XCUIApplication,
  size classes), or distribution (code signing, App Store Connect, TestFlight,
  App Review, localization with String(localized:) and .xcstrings) for
  iOS/iPadOS 26 apps.
---

Implement accessibility, privacy, performance, testing, distribution, and localization correctly for iOS/iPadOS 26 apps built with Xcode 26.

## Use this skill when

- Adding `.accessibilityLabel`/`.accessibilityHint`/`.accessibilityValue` or grouping elements with `.accessibilityElement(children:)`.
- Supporting Dynamic Type, `.accessibilityReduceMotion`, or `.accessibilityReduceTransparency`.
- Adding an Info.plist usage-description key (e.g. `NSCameraUsageDescription`) or calling `ATTrackingManager.requestTrackingAuthorization`.
- Creating or updating `PrivacyInfo.xcprivacy` for a required-reason API.
- Profiling with Instruments, fixing main-thread stalls, or tuning `List`/image-loading performance.
- Writing `XCUIApplication`-based UI tests or testing across size classes/iPad windowing.
- Setting up code signing, an App Store Connect record, or a TestFlight build.
- Localizing strings with `String(localized:)`/`.xcstrings` or checking right-to-left mirroring.

## Do not use this skill when

- Choosing colors/typography or basic input-gesture behavior — use ios-hig-foundations or ios-hig-inputs (come back here for the accessibility *implementation* details).
- Structuring the app/state itself — use ios-app-architecture.
- Choosing which component or layout pattern to use — use ios-hig-patterns or ios-hig-components-structure/ios-hig-components-controls.
- Deciding standard control semantics (e.g. whether a control should be a button vs. a toggle) — use ios-hig-components-controls, then return here for its accessibility label/hint.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested requirement is satisfied.

1. Identify the concern (accessibility/privacy, performance/testing, or distribution/localization) and open EXACTLY ONE reference file from the list below.
2. Request the narrowest permission/API that satisfies the feature — never request tracking authorization or a broad permission "just in case."
3. Add accessibility labels/hints/values alongside the control that needs them, not as a separate afterthought pass.
4. Declare any required-reason API used (e.g. `UserDefaults`, file timestamps) in `PrivacyInfo.xcprivacy` with an approved reason code at the same time you write the code that calls it.
5. Add the matching Info.plist usage-description string whenever you add a permission-gated API call.
6. For performance/testing work, verify with the concrete tool named in the reference (Instruments template, `xcodebuild test`) rather than guessing.
7. For distribution/localization work, apply the smallest change that unblocks the current build or string — do not restructure signing or the whole localization catalog speculatively.
8. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not request broad permissions or tracking authorization "just in case"; request only what the current feature needs.
- Stop as soon as the requirement (accessibility label, permission, signed build, localized string, etc.) is satisfied.

## Reference files

- `references/accessibility-privacy-tracking.md` — open when adding VoiceOver/accessibility modifiers, Dynamic Type or Reduce Motion/Transparency support, an Info.plist usage-description key, ATT tracking authorization, or a `PrivacyInfo.xcprivacy` entry.
- `references/performance-testing.md` — open when profiling with Instruments, fixing `List`/image-loading/main-thread performance issues, or writing `XCUIApplication` UI tests.
- `references/distribution-app-store-localization.md` — open when configuring code signing, App Store Connect/TestFlight, App Review compliance, or localizing strings with `String(localized:)`/`.xcstrings`.
