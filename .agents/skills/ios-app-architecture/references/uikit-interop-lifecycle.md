# UIKit Interop and App Lifecycle

## When to drop to UIKit

Reach for UIKit only when SwiftUI has no equivalent: a specific `UIKit`/third-party control (e.g., `PDFView`, a camera picker, a `UICollectionView` compositional layout with behavior SwiftUI's `List`/`Grid` can't match), or fine-grained scroll/gesture control. Wrap the smallest possible surface — a single control, not a whole screen — so the rest of the feature stays in SwiftUI.

## UIViewRepresentable

Conform to `UIViewRepresentable` to host a `UIView` inside SwiftUI. `makeUIView` creates it once; `updateUIView` runs whenever SwiftUI-owned state changes.

```swift
struct MapMarkerView: UIViewRepresentable {
    var coordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        MKMapView()
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setCenter(coordinate, animated: true)
    }
}
```

Use `Coordinator` (via `makeCoordinator()`) to act as the `UIView`'s delegate and forward events back into SwiftUI with a closure or binding.

```swift
struct SearchBarView: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> UISearchBar {
        let bar = UISearchBar()
        bar.delegate = context.coordinator
        return bar
    }

    func updateUIView(_ bar: UISearchBar, context: Context) {
        bar.text = text
    }

    final class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        init(text: Binding<String>) { self._text = text }
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }
    }
}
```

## UIViewControllerRepresentable

Same pattern for wrapping a `UIViewController` — use this for camera pickers, document pickers, or any controller-based UIKit API.

```swift
struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            urls.first.map(onPick)
        }
    }
}
```

## UIHostingController: embedding SwiftUI in UIKit

Going the other direction — a UIKit-based app or screen that needs a SwiftUI subtree — wrap the SwiftUI view in `UIHostingController` and add it as a child.

```swift
let detailView = UIHostingController(rootView: RecipeDetailView(recipeID: recipeID))
addChild(detailView)
view.addSubview(detailView.view)
detailView.didMove(toParent: self)
```

Prefer this when migrating a UIKit app to SwiftUI incrementally, screen by screen, rather than rewriting everything at once.

## App/Scene lifecycle basics

SwiftUI's `App`/`Scene` types replace `AppDelegate`/`SceneDelegate` for most lifecycle needs. `Scene` corresponds to a `UIWindowScene`; each `WindowGroup` window the system creates is backed by one.

```swift
@main
struct RecipeApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

## @UIApplicationDelegateAdaptor

Use `@UIApplicationDelegateAdaptor` when you still need `UIApplicationDelegate` callbacks (push notification registration, `application(_:didFinishLaunchingWithOptions:)`, background URL session handling) that SwiftUI's `App` doesn't expose directly.

```swift
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
        return true
    }
}

@main
struct RecipeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene { WindowGroup { ContentView() } }
}
```

## scenePhase

`@Environment(\.scenePhase)` reports `.active`, `.inactive`, or `.background` for the current scene — use it to pause/resume work (timers, network polling) or save state, instead of overriding UIKit lifecycle methods.

```swift
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RecipeListView()
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    PersistenceController.shared.save()
                }
            }
    }
}
```

Read `scenePhase` at (or near) the `App`/root-view level so lifecycle-driven work stays centralized rather than scattered across leaf views.

## Widgets and app extensions as an architectural consideration

A WidgetKit widget is a separate extension target with its own `TimelineProvider`/`AppIntentTimelineProvider` and SwiftUI view — it does not share your app's live process or in-memory state. Share data via an App Group container (shared `UserDefaults`/file container/SwiftData store), and call `WidgetCenter.shared.reloadTimelines(ofKind:)` from the main app when underlying data changes so the widget's next render picks it up. Treat widget-eligible state as a distinct, serializable slice of your model from the start rather than trying to retrofit sharing later.
