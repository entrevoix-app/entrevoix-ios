# Search, Settings, Undo, Notifications, Offline, Onboarding, Printing, Reviews, Drag and Drop

## Search with .searchable

Attach `.searchable` to the view that owns the content being searched (usually a `NavigationStack` root), not to an arbitrary child, and filter as the person types rather than requiring a submit tap. Use `.searchScopes` for scoped filters (e.g., "All / Unread") only when there are a handful of well-known categories, and mark results live so an agent-driven UI test sees the list update on every keystroke rather than after a delay.

```swift
NavigationStack {
    List(filteredItems) { ItemRow(item: $0) }
        .searchable(text: $query, prompt: "Search Items")
        .searchScopes($scope) {
            ForEach(Scope.allCases) { Text($0.label).tag($0) }
        }
}
```

## In-app settings vs the system Settings app

Put settings the person adjusts often, or that change what they immediately see (theme, sort order, display units), inside the app's own settings screen. Put anything that is a system-level permission or account-level toggle (notifications permission, location permission, cellular data, default apps) in the system Settings app, and link to your app's page there with `UIApplication.openSettingsURLString` instead of trying to replicate the control yourself.

```swift
Button("Open Settings") {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}
```

## Undo and redo

Wire real edits through `UndoManager` (available via `@Environment(\.undoManager)` in SwiftUI, or `UIResponder.undoManager` in UIKit) so shake-to-undo and the standard three-finger swipe/undo gesture work automatically, and surface an explicit "Undo" affordance in a toolbar or the transient banner for actions that aren't obviously reversible by shaking. Register the inverse operation at the moment of the edit, not after the fact, so multi-step undo stays consistent.

```swift
@Environment(\.undoManager) private var undoManager

func delete(_ item: Item) {
    let index = items.firstIndex(of: item)!
    items.remove(at: index)
    undoManager?.registerUndo(withTarget: self) { target in
        target.items.insert(item, at: index)
    }
}
```

## Local notifications

Request notification permission with `UNUserNotificationCenter.current().requestAuthorization` only right before scheduling the first notification the person has a concrete reason to want (after they set a reminder, not on first launch), and explain in-context what it's for before the system prompt appears. Use local notifications for on-device, time- or event-based reminders the app itself can schedule (a timer finishing, a reminder time arriving); use remote push instead for anything server-driven.

```swift
let center = UNUserNotificationCenter.current()
center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
    guard granted else { return }
    let content = UNMutableNotificationContent()
    content.title = "Reminder"
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
}
```

## Offline experiences

Design every screen to degrade gracefully rather than showing a dead end: serve cached data with a subtle "offline" indicator instead of a blocking error, queue writes locally and sync when connectivity returns, and disable (don't hide) actions that require the network so their intent stays visible. Monitor reachability with `NWPathMonitor` and only surface a banner on an actual status change, not on every check.

```swift
let monitor = NWPathMonitor()
monitor.pathUpdateHandler = { path in
    isOffline = path.status != .satisfied
}
monitor.start(queue: .main)
```

## Onboarding

Keep onboarding to the minimum needed to reach first value, make every step skippable, and prefer contextual, just-in-time tips (a coach mark the first time a feature appears) over a multi-page walkthrough shown before the person has done anything. Never gate core functionality behind onboarding that can't be skipped or replayed later from settings/help.

## Printing

Use `UIPrintInteractionController` for print jobs, and provide a proper printable representation (formatted HTML, a `UIPrintFormatter`, or a rendered `UIImage`/PDF) rather than dumping raw on-screen views. Present the print sheet from the control that triggered it — on iPad this naturally becomes a popover; on iPhone it presents as a sheet — and let the system UI handle printer selection, page range, and copies.

```swift
let printController = UIPrintInteractionController.shared
printController.printingItem = pdfData
printController.present(animated: true)
```

## Requesting App Store ratings and reviews

Call `requestReview(...)` (the `@Environment(\.requestReview)` action in SwiftUI, backed by `SKStoreReviewController`) only after a moment of clear success — a completed task, a milestone reached — never immediately after launch, never after an error, and never more than a few times a year; the system itself throttles and may silently skip the prompt, so don't retry if nothing appears. Never build a custom "rate us" dialog that gates app functionality or nags on every launch.

```swift
@Environment(\.requestReview) private var requestReview

func didCompleteMilestone() {
    requestReview()
}
```

## Drag and drop, including iPad multi-app drag and drop

Make draggable content real data (text, images, URLs, `Transferable` items), not just visuals, using `.draggable(_:)` and accept it with `.dropDestination(for:)` so drags work both within the app and, on iPad, between two apps on screen at once. Give clear visual feedback during a drag (a lift effect, a drop-target highlight) and validate dropped content type before accepting it rather than crashing or silently discarding unsupported drops.

```swift
Text(item.title)
    .draggable(item)

List {
    ForEach(items) { ItemRow(item: $0) }
}
.dropDestination(for: Item.self) { droppedItems, _ in
    items.append(contentsOf: droppedItems)
    return true
}
```
