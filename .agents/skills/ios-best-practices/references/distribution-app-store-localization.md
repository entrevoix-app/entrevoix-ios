# Distribution, App Store, and Localization

## Code signing concepts

A build is signed with a certificate (identity), provisioning profile (which devices/capabilities/entitlements are allowed), and an App ID (bundle identifier); Xcode 26 manages all three automatically per target under Signing & Capabilities when "Automatically manage signing" is checked.

```bash
security find-identity -v -p codesigning
xcodebuild -showBuildSettings -scheme AppName | grep -i "CODE_SIGN\|PROVISIONING"
```

Distribution (App Store/TestFlight) archives require a "Distribution" certificate and an App Store provisioning profile, distinct from the "Development" certificate/profile used for device testing.

## Automatic vs. manual signing

Automatic signing (default, recommended) lets Xcode create/renew certificates and profiles via your Apple Developer account; manual signing requires selecting an explicit provisioning profile per build configuration and is typically only needed for CI, Fastlane `match`, or enterprise distribution workflows with fixed profiles.

```
Target > Signing & Capabilities
  [x] Automatically manage signing
  Team: Your Team
  Bundle Identifier: com.yourcompany.appname
```

```bash
xcodebuild -exportArchive -archivePath App.xcarchive -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

Switch to manual signing only when automatic signing can't satisfy a specific requirement (e.g. a fixed CI profile, enterprise/ad hoc distribution) — do not switch speculatively.

## Archiving and uploading

Archive from Xcode (Product > Archive) or the command line, then upload either straight from the Organizer window (Window > Organizer > Distribute App) or via `xcodebuild -exportArchive` with a `destination: upload` export-options plist, which validates and uploads in one step — `altool` is retired for this purpose; use the standalone **Transporter** app only as a fallback for uploading an already-exported `.ipa`.

```bash
xcodebuild archive -scheme AppName -archivePath ./build/App.xcarchive
xcodebuild -exportArchive -archivePath ./build/App.xcarchive -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates
# ExportOptions.plist sets <key>destination</key><string>upload</string> to upload directly,
# or <string>export</string> to just produce an .ipa for Transporter.
```

Missing `PrivacyInfo.xcprivacy` entries or usage-description strings surface here as `ITMS-*` validation errors before the build ever reaches App Store Connect.

## App Store Connect

App Store Connect (appstoreconnect.apple.com) is where you create the app record, fill in metadata (name, description, screenshots), answer the App Privacy questionnaire (data collection types, linked-to-user, tracking), set pricing/availability, and submit builds for review.

The App Privacy answers must match both the runtime behavior and the `PrivacyInfo.xcprivacy` manifest — a common rejection is declaring "No" for tracking in App Store Connect while `NSPrivacyTracking` is `true` (or `ATTrackingManager` is called) in the binary.

## TestFlight internal and external testing

Internal testers are existing App Store Connect Users and Access members (added instantly, no review) with a cap on internal tester count per app; external testers are invited via public/email links and require a Beta App Review pass (similar to, but lighter than, full App Review) before the first build in a group goes out. Any build uploaded via Organizer, `xcodebuild -exportArchive` (upload destination), or Transporter automatically becomes available to assign to TestFlight groups once processing finishes.

TestFlight builds expire 90 days after upload; re-upload a fresh build before then to keep a beta group testable, and use build-number bumps (`CFBundleVersion`) for every new upload since App Store Connect requires a unique build number per version.

## App Review guideline highlights (common rejections)

Guideline 5.1.1 (Data Collection and Storage) rejections usually trace back to a missing/misleading usage-description string or an App Privacy declaration that doesn't match behavior; Guideline 2.1 (App Completeness) covers crashes/placeholder content found during review; Guideline 4.0 (Design) covers HIG deviations like non-standard status bars or broken navigation.

- Request permissions with a clear, specific usage string — vague text ("this app needs your location") is a frequent 5.1.1 flag.
- Don't call `ATTrackingManager.requestTrackingAuthorization` if the app doesn't actually track — Apple checks this against the App Privacy questionnaire.
- Provide demo credentials or a fully-working demo account in App Review notes if the app requires login, or review is blocked (Guideline 2.1).
- Make sure every screenshot/preview reflects the current build's actual UI (Guideline 2.3.3).

## Localization with String(localized:) and .xcstrings

`String(localized:)` replaces the older `NSLocalizedString` macro-based flow and is extracted automatically into a `.xcstrings` String Catalog, which Xcode 26 edits in a dedicated table UI (source string, state, translations per language).

```swift
Text(String(localized: "welcome_message", defaultValue: "Welcome back, \(userName)!"))

Label(String(localized: "settings.title", table: "Settings"), systemImage: "gear")
```

Add a `.xcstrings` file via File > New > File > String Catalog, then add target languages in the catalog's language picker; Xcode flags strings marked "New" or "Needs Review" so you can track translation completeness per language.

## Pluralization

String Catalogs support plural variants (`zero`/`one`/`two`/`few`/`many`/`other` per CLDR rules) authored directly in the `.xcstrings` table UI, or via `String(localized:)` with a format that references an `Int`.

```swift
Text("\(itemCount) items remaining", tableName: "Cart")
// In the .xcstrings editor: set the variant type to "Plural" and fill in
// the "one" (1 item remaining) and "other" (%lld items remaining) forms.
```

Never hand-roll plural logic with `count == 1 ? "item" : "items"` — it breaks for languages with more than two plural forms (e.g. Arabic, Polish); let the String Catalog's plural rules handle it per locale.

## Right-to-left layout mirroring

SwiftUI's layout system mirrors leading/trailing edges, `HStack` order, and most system icons automatically for RTL languages (Arabic, Hebrew) as long as you use `.leading`/`.trailing` alignment and semantic icons rather than hardcoded `.left`/`.right` or direction-specific chevrons.

```swift
HStack {
    Image(systemName: "chevron.backward") // mirrors correctly; avoid "chevron.left"
    Text("Back")
}
.environment(\.layoutDirection, .rightToLeft) // preview-only override for testing
```

Test RTL by adding an RTL language as a run-scheme override (Product > Scheme > Edit Scheme > Options > App Language) rather than only relying on the `.environment` preview override, since some mirroring only applies at the app/window level.
