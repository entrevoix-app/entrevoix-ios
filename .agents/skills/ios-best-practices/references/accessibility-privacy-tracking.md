# Accessibility, Privacy, and Tracking

## VoiceOver labels, hints, and values

Every interactive control needs a label; use hint sparingly for non-obvious outcomes, and value for controls whose state VoiceOver can't infer from the label alone.

```swift
Button {
    toggleFavorite()
} label: {
    Image(systemName: isFavorite ? "star.fill" : "star")
}
.accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
.accessibilityHint("Double-tap to toggle favorite status")

Slider(value: $volume, in: 0...1)
    .accessibilityLabel("Volume")
    .accessibilityValue("\(Int(volume * 100)) percent")
```

Do not append redundant words like "button" — VoiceOver already announces the trait. Set labels on the same view modification that adds the control, not in a separate pass at the end of a feature.

## Grouping and hiding elements

Use `.accessibilityElement(children: .combine)` to merge a cluster of `Text`/`Image` views (e.g. a card) into one swipe stop, and `.accessibilityHidden(true)` on purely decorative views.

```swift
VStack(alignment: .leading) {
    Text(restaurant.name).font(.headline)
    Text(restaurant.cuisine).font(.subheadline)
}
.accessibilityElement(children: .combine)

Image("decorativeBackground")
    .accessibilityHidden(true)
```

`.accessibilityElement(children: .ignore)` plus an explicit `.accessibilityLabel` lets you author a custom announcement instead of concatenating child text; use `.combine` when the concatenation already reads naturally.

## Dynamic Type

Prefer semantic text styles over fixed point sizes so text scales with the user's chosen size, and test at `.accessibility5` (the largest accessibility size).

```swift
Text("Order confirmed")
    .font(.headline) // scales automatically

Text("Order confirmed")
    .font(.system(size: 17, weight: .semibold))
    .dynamicTypeSize(...DynamicTypeSize.accessibility3) // clamp only when layout truly can't scale further
```

Avoid `.fixedSize()` on text that must scale, and check that `HStack` layouts with fixed-width siblings don't clip at larger sizes — switch to `ViewThatFits` or a `VStack` fallback if they do.

## Reduce Motion and Reduce Transparency

Read the environment values and provide a non-animated / opaque fallback rather than ignoring the setting.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

withAnimation(reduceMotion ? nil : .spring()) {
    isExpanded.toggle()
}

.background(reduceTransparency ? Color(.systemBackground) : .clear.background(.ultraThinMaterial))
```

## Testing with the Accessibility Inspector and Switch Control

Run `xcrun simctl` to launch the simulator, then open the Accessibility Inspector (Xcode > Open Developer Tool > Accessibility Inspector) and point it at the running app or simulator to audit labels, run the built-in Audit, and inspect the element tree.

```bash
xcrun simctl list devices
open -a "Accessibility Inspector"
```

Also enable VoiceOver (Settings > Accessibility > VoiceOver) and Switch Control on-device or in Simulator (Features > Accessibility) to confirm focus order is logical and every actionable element is reachable — Switch Control relies on the same accessibility tree, so a missing label breaks both.

## Info.plist usage-description keys

Every privacy-sensitive API requires a matching usage-description string in Info.plist, worded to explain why *this app* needs it; a missing key crashes the app on first use and a generic string ("we need this permission") is a common App Review rejection reason.

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access lets you scan receipts to add expenses.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location helps us show nearby stores.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Save your edited photos to your library.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Record audio notes for your entries.</string>
```

Request the permission at the point of use (e.g. when the user taps "Scan Receipt"), not at launch, so the system prompt has clear context.

## App Tracking Transparency

Call `ATTrackingManager.requestTrackingAuthorization` only if the app links cross-app/cross-site activity to a third party (ad attribution, cross-app identifiers); it requires `NSUserTrackingUsageDescription` and must not be called before the app is foregrounded and ready to show the prompt.

```swift
import AppTrackingTransparency

func requestTrackingIfNeeded() async {
    guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
    let status = await ATTrackingManager.requestTrackingAuthorization()
    switch status {
    case .authorized: enableAttributedAds()
    case .denied, .restricted, .notDetermined: disableAttributedAds()
    @unknown default: disableAttributedAds()
    }
}
```

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Your data will be used to show you more relevant ads.</string>
```

Do not gate core functionality behind this prompt, and do not call it repeatedly — check `ATTrackingManager.trackingAuthorizationStatus` first and only prompt once per `notDetermined` state.

## PrivacyInfo.xcprivacy and required-reason APIs

Add a `PrivacyInfo.xcprivacy` file (a property list) to any target — app or third-party SDK — that calls a "required-reason API" (e.g. `UserDefaults`, file timestamp APIs, disk space APIs, active keyboard APIs, system boot time), declaring the exact approved reason code; Xcode 26 flags missing manifests at archive/upload time (`ITMS-91053`/`ITMS-91055`).

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Set `NSPrivacyTracking` to `true` and list `NSPrivacyTrackingDomains` if the app performs tracking as defined by Apple; list any data types actually collected (e.g. email address, coarse location) under `NSPrivacyCollectedDataTypes` matching what is declared in App Store Connect's App Privacy questionnaire — mismatches between the manifest, the questionnaire, and actual behavior are a rejection/removal risk.

## Minimizing data collection

Collect the smallest data set the feature needs, prefer on-device processing (e.g. `Vision`/`Natural Language` frameworks) over sending raw data to a server, and avoid persisting data (location history, contacts) longer than the feature requires — this reduces both privacy-manifest surface area and App Review scrutiny.
