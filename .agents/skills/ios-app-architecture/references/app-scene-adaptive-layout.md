# App, Scene, and Adaptive Layout

## The App protocol and @main

Every SwiftUI app has exactly one type conforming to `App`, marked `@main`, whose `body` returns one or more `Scene`s. This replaces `AppDelegate`/`SceneDelegate` as the entry point for app-level state.

```swift
@main
struct RecipeApp: App {
    @State private var library = RecipeLibrary()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
        }
    }
}
```

Put shared, app-lifetime state (a data store, an `@Observable` model) here and inject it with `.environment(_:)` rather than constructing it inside a view.

## WindowGroup and multi-window on iPad

`WindowGroup` describes a family of windows the system can create on demand. On iPadOS 26, users can open additional windows of the same `WindowGroup` (freely resizable, with a menu bar), and on macOS/Catalyst each instance is a separate window. Design for a single window first; multi-window is a bonus the same `WindowGroup` gets for free, not a reason to fork your view hierarchy.

```swift
WindowGroup(id: "recipe-detail", for: Recipe.ID.self) { $recipeID in
    RecipeDetailView(recipeID: recipeID)
}
```

Use `WindowGroup(for:)` with a value type when a window should present a specific piece of data (e.g., opening a recipe in its own window); open new windows with `openWindow(id:value:)` from `@Environment(\.openWindow)`.

```swift
struct RecipeRow: View {
    @Environment(\.openWindow) private var openWindow
    let recipe: Recipe

    var body: some View {
        Button("Open in New Window") {
            openWindow(id: "recipe-detail", value: recipe.id)
        }
    }
}
```

## Size classes

`horizontalSizeClass` and `verticalSizeClass` report `.compact` or `.regular` for the current window, not the physical device — an iPad in Slide Over or a resized iPadOS 26 window can report `.compact` just like an iPhone.

```swift
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .compact {
            NavigationStack { RecipeListView() }
        } else {
            RecipeSplitView()
        }
    }
}
```

Never branch on `UIDevice.current.userInterfaceIdiom` for layout decisions — branch on size class so the same code adapts correctly to a resized iPad window or an iPhone in landscape.

## NavigationSplitView collapsing behavior

`NavigationSplitView` automatically collapses to a single-column stack (behaving like `NavigationStack`) at compact width and expands to two or three columns at regular width — you don't need an `if/else` on size class just to switch containers.

```swift
NavigationSplitView {
    List(recipes, selection: $selectedRecipeID) { recipe in
        NavigationLink(recipe.name, value: recipe.id)
    }
} detail: {
    if let selectedRecipeID {
        RecipeDetailView(recipeID: selectedRecipeID)
    } else {
        ContentUnavailableView("Select a Recipe", systemImage: "fork.knife")
    }
}
```

Set `navigationSplitViewColumnWidth(min:ideal:max:)` or `.navigationSplitViewStyle(_:)` to tune column behavior; the default `.automatic` style already handles compact collapse correctly, so add styling only if the default look is wrong.

## Verifying phone-first, then iPad/multi-window

Build and test the compact (iPhone) layout first, since it's the strictest constraint. Then verify on iPad: (1) at full-screen regular width, (2) in a resized/Split View iPad window (which can force `.compact` again), and (3) with an additional `WindowGroup` window open if the app supports it. A layout that only works at one fixed width is a bug, not a design choice.

```swift
ContentView()
    .previewLayout(.sizeThatFits)
```

Use `#Preview` with different `.previewDevice` values (or resize the canvas) to sanity-check both size classes before considering the layout done.

## Toolbar and title adaptivity

`.navigationTitle` and `.toolbar` content should be defined once and let the system adapt placement (e.g., `ToolbarItemPlacement.principal` vs trailing) rather than duplicating toolbars per size class.

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button("Add", systemImage: "plus") { isAddingRecipe = true }
    }
}
```

Placements like `.primaryAction` and `.navigation` resolve differently on compact vs regular width automatically — avoid hardcoding `.navigationBarTrailing` unless you specifically need iPhone-style bar semantics.
