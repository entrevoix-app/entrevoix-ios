# Performance and Testing

## Profiling with Instruments

Launch Instruments from Xcode (Product > Profile, or `Cmd+I`) or directly, and pick the **Time Profiler** template to find hot call stacks, or the **SwiftUI** instrument to see view body re-evaluations and identity churn.

```bash
xcrun xctrace record --template "Time Profiler" --launch /path/to/App.app --output trace.trace
xcrun xctrace record --template "SwiftUI" --attach "AppName" --output swiftui.trace
```

Always profile a Release-configuration build on-device (not Simulator) before drawing conclusions — Simulator CPU/GPU behavior does not match device thermals or memory pressure.

## Avoiding main-thread blocking

Keep the main thread free for layout/animation by moving I/O, parsing, and heavy computation to background tasks and only touching UI state on the main actor.

```swift
func loadFeed() async {
    let data = try? await URLSession.shared.data(from: feedURL).0
    let items = await Task.detached { () -> [FeedItem] in
        try? JSONDecoder().decode([FeedItem].self, from: data ?? Data()) ?? []
    }.value
    await MainActor.run { self.items = items }
}
```

Watch for accidental synchronous work in `body`, `onAppear`, or Core Data fetches on the main context — the Time Profiler's main-thread track and the "Hangs" instrument both surface these directly.

## List performance with large datasets

Let `List`/`LazyVStack` lazily materialize rows, give each row a stable `id`, and avoid heavy per-row work (image decoding, date formatting) inside the row's `body` — precompute or cache it instead.

```swift
List(items) { item in
    FeedRow(item: item)          // stable Identifiable id, lightweight body
        .id(item.id)
}
.listStyle(.plain)
```

For datasets in the thousands, prefer `LazyVStack` inside a `ScrollView` only when you need custom layout `List` can't do, and paginate data fetches instead of loading everything up front.

## Image loading and caching

Downsample images to their display size before caching (`UIGraphicsImageRenderer` or `CGImageSourceCreateThumbnailAtIndex`) rather than decoding full-resolution images into memory, and cache decoded images in an `NSCache` (which purges under memory pressure) rather than a plain dictionary.

```swift
let imageCache = NSCache<NSString, UIImage>()

func thumbnail(for url: URL, maxPixelSize: CGFloat) -> UIImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        kCGImageSourceCreateThumbnailWithTransform: true
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return UIImage(cgImage: cgImage)
}
```

`AsyncImage` is fine for a handful of images but has no shared cache across views — for feeds/grids, use a caching image pipeline (custom `NSCache` wrapper or a library) to avoid re-downloading/re-decoding on every scroll.

## Launch-time budget

Defer any work not needed for the first frame (analytics SDK init, prefetching, background sync) until after the first screen is interactive, and measure with the "App Launch" Instruments template, which breaks launch into pre-main, `didFinishLaunching`, and first-frame phases.

```bash
xcrun xctrace record --template "App Launch" --launch /path/to/App.app --output launch.trace
```

Apple's general guidance is to get to first interactive frame quickly; heavy synchronous work in `App.init()`, `AppDelegate.didFinishLaunching`, or a scene's first `onAppear` is the most common cause of a slow launch.

## XCTest / Swift Testing UI tests

Use `XCUIApplication` to drive the app like a user and assert on the accessibility tree — this is also why accessibility labels matter for testability, not just VoiceOver.

```swift
import XCTest

final class CheckoutUITests: XCTestCase {
    func testCompletesCheckout() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Add to Cart"].tap()
        app.buttons["Checkout"].tap()
        XCTAssertTrue(app.staticTexts["Order confirmed"].waitForExistence(timeout: 5))
    }
}
```

Swift Testing (`import Testing`, `@Test`) is preferred for new unit tests (`#expect`, `#require`) but UI automation still goes through `XCTest`'s `XCUIApplication`; both test targets can coexist in one scheme.

```bash
xcodebuild test -scheme AppName -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Testing across size classes and iPad windowing

Drive the same UI tests against multiple simulators/destinations to catch layout breaks in compact vs. regular width, and manually verify iPad Split View, Slide Over, and Stage Manager resizing since those windowing states aren't fully reproducible via `XCUIApplication` alone.

```bash
xcodebuild test -scheme AppName -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'
xcodebuild test -scheme AppName -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'
```

In SwiftUI previews, use `.previewDevice(...)` combined with different `horizontalSizeClass`/`verticalSizeClass` environment overrides to spot-check adaptive layouts before running full UI tests.
