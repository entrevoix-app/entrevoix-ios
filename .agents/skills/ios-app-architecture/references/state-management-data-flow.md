# State Management and Data Flow

## @State for local, transient view state

`@State` owns a value that belongs to a single view — a toggle, a text field draft, a sheet's `isPresented` flag. Default to it for anything that doesn't need to be shared.

```swift
struct RecipeSearchField: View {
    @State private var query = ""

    var body: some View {
        TextField("Search", text: $query)
    }
}
```

`@State` can also own a reference-type `@Observable` model when a view is the sole owner of that model's lifetime (replacing the old `@StateObject` role).

```swift
struct RecipeListView: View {
    @State private var viewModel = RecipeListViewModel()

    var body: some View {
        List(viewModel.recipes) { RecipeRow(recipe: $0) }
            .task { await viewModel.load() }
    }
}
```

## @Binding for two-way child access

`@Binding` gives a child view read/write access to state owned by a parent, without the child owning it.

```swift
struct FavoriteToggle: View {
    @Binding var isFavorite: Bool

    var body: some View {
        Toggle("Favorite", isOn: $isFavorite)
    }
}
```

Pass bindings down explicitly (`FavoriteToggle(isFavorite: $recipe.isFavorite)`); don't reach for `@Environment` just to avoid threading a binding through one or two view levels.

## @Observable and @Bindable (modern default)

Mark a model class `@Observable` (from the `Observation` framework) instead of conforming to `ObservableObject` with `@Published` properties. Views that read an `@Observable` model's properties are automatically tracked and only re-render when those specific properties change.

```swift
import Observation

@Observable
final class RecipeListViewModel {
    var recipes: [Recipe] = []
    var isLoading = false

    func load() async { /* ... */ }
}
```

Use plain `let`/property access for an `@Observable` model passed in as a constant reference; use `@Bindable` only when you need a `$`-binding into one of its properties.

```swift
struct RecipeDetailView: View {
    @Bindable var recipe: Recipe   // Recipe is @Observable

    var body: some View {
        TextField("Name", text: $recipe.name)
    }
}
```

## @Environment for dependency injection

`@Environment` reads a value placed by an ancestor with `.environment(_:)`. Use it to inject shared `@Observable` services (a data store, an auth session) without passing them through every initializer.

```swift
@main
struct RecipeApp: App {
    @State private var session = UserSession()
    var body: some Scene {
        WindowGroup { RootView().environment(session) }
    }
}

struct RootView: View {
    @Environment(UserSession.self) private var session
    var body: some View { Text(session.userName) }
}
```

`@Environment` also reads system-provided keys like `\.horizontalSizeClass`, `\.scenePhase`, `\.openWindow`, and `\.dismiss` — same mechanism, no custom key needed for those.

## Legacy ObservableObject types

`@StateObject`, `@ObservedObject`, and `@EnvironmentObject` are the pre-Observation equivalents for `ObservableObject` classes using `@Published`. They still work and appear throughout older codebases; the mapping to modern equivalents is `@StateObject` → `@State`, `@ObservedObject`/property → `@Bindable`/plain property, `@EnvironmentObject` → `@Environment(Type.self)`.

```swift
final class LegacyStore: ObservableObject {
    @Published var items: [Item] = []
}

struct LegacyListView: View {
    @StateObject private var store = LegacyStore()
    var body: some View { List(store.items) { Text($0.name) } }
}
```

Don't mix `ObservableObject` and `@Observable` for the same model type, and don't migrate a whole working legacy hierarchy mid-task unless migration is the actual assignment — match the surrounding code's existing pattern.

## MV vs MVVM: keeping views thin

"MV" (model-view) uses an `@Observable` domain/data model directly as the view's state source, with no separate view-model layer; SwiftUI's declarative body plus `@Observable` already does most of what a view-model used to do. Reach for an explicit view-model (MVVM) when a screen has non-trivial presentation logic (formatting, validation, orchestrating multiple async calls) that would otherwise bloat the view body.

```swift
// MV: the view reads the domain model directly.
struct RecipeRow: View {
    let recipe: Recipe
    var body: some View { Text(recipe.name) }
}

// MVVM: a view-model mediates between domain model and view.
@Observable
final class RecipeRowViewModel {
    private let recipe: Recipe
    init(recipe: Recipe) { self.recipe = recipe }
    var formattedCookTime: String { /* formatting logic */ "" }
}
```

Whichever pattern you pick, keep the `View.body` free of business logic, networking, and persistence calls — those belong in the model or view-model, called from `.task`/`.onAppear`/button actions.

## Data flow direction

Data should flow down (`@State` → `@Binding`/child parameters) and events flow up (closures, `@Bindable` writes, or calls into an injected `@Observable` service). Avoid a child view reaching sideways into a sibling's state — route it back up through the shared owner or a shared `@Environment` service instead.
