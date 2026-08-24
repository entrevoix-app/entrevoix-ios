# Navigation Bars, Tab Bars, and Toolbars (iOS/iPadOS 26)

## NavigationStack is the default navigation container

Wrap each independent navigation flow in exactly one `NavigationStack`, driving pushes with `NavigationLink` or a `path` binding rather than manual view-swapping. Don't nest a second `NavigationStack` inside a pushed view — that breaks the back button and swipe-back gesture.

```swift
struct InboxView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List(messages) { message in
                NavigationLink(message.subject, value: message.id)
            }
            .navigationTitle("Inbox")
            .navigationDestination(for: Message.ID.self) { id in
                MessageDetailView(messageID: id)
            }
        }
    }
}
```

## Navigation titles and large title display mode

Give every root screen a `.navigationTitle` — it's what the back button falls back to on the next screen and what VoiceOver announces. Use `.navigationBarTitleDisplayMode(.large)` for top-level, browsing-style screens (lists, feeds) and `.inline` for detail/editing screens where a large title would waste vertical space. Let the title collapse to inline automatically on scroll for `.automatic`/`.large` rather than fighting it.

```swift
List(albums) { album in
    NavigationLink(album.title, value: album.id)
}
.navigationTitle("Albums")
.navigationBarTitleDisplayMode(.large)
```

Detail screens pushed from a list should typically use `.inline` so the title doesn't compete with content near the top:

```swift
AlbumDetailView(album: album)
    .navigationTitle(album.title)
    .navigationBarTitleDisplayMode(.inline)
```

## TabView and the Tab struct

Use `TabView` for the app's top-level destinations — the ones a user should be able to jump to directly at any time. Build each tab with the `Tab` value type (not a bare `.tabItem` on arbitrary views) so the system can manage selection, and give each tab a stable identity via `value:` when tabs can reorder or when driving selection programmatically.

```swift
struct RootView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                SearchView()
            }
            Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) {
                ProfileView()
            }
        }
    }
}
```

Keep top-level tabs to 5 or fewer — HIG's Tab Bars guidance treats the tab bar as a small, stable set of primary destinations, not a dumping ground for every feature. Give a search-oriented tab `role: .search`; the system separates it visually (and, on iPadOS, can place it opposite the other tabs) instead of treating it as an ordinary destination.

## The iOS 26 floating Liquid Glass tab bar

On iOS 26 the tab bar renders as a translucent, floating Liquid Glass bar rather than an opaque bottom bar — this is automatic for any standard `TabView`; don't try to recreate the old opaque bar with a custom background. For content that scrolls beneath the tab bar (feeds, long lists), control whether the bar minimizes as the user scrolls with `.tabBarMinimizeBehavior`:

```swift
TabView(selection: $selection) {
    Tab("Feed", systemImage: "list.bullet", value: AppTab.feed) {
        FeedView()
    }
    Tab("Home", systemImage: "house", value: AppTab.home) {
        HomeView()
    }
}
.tabBarMinimizeBehavior(.onScrollDown)
```

`.automatic` lets the system decide per platform, `.never` keeps the bar fully visible, and `.onScrollDown`/`.onScrollUp` collapse the bar to a compact form as scrolling starts in that direction (iPhone only — iPad keeps the bar visible). Don't set `.never` on a content-dense scrolling screen just to avoid the collapse animation; it works against the platform's design language.

## Tab badges

Use `.badge` on a `Tab` to surface an unread count or attention indicator — a small number or dot, not a full sentence. Clear the badge as soon as the underlying content has been seen; a badge that never updates trains users to ignore it.

```swift
Tab("Messages", systemImage: "message", value: AppTab.messages) {
    MessagesView()
}
.badge(unreadCount)
```

## Bottom accessory content above the tab bar

For a small, persistent control that should float just above the tab bar (a mini player, a live activity-style status), use `.tabViewBottomAccessory` rather than embedding it inside one tab's content — it stays put across tab switches and integrates with the bar's minimize behavior.

```swift
TabView(selection: $selection) {
    // tabs...
}
.tabViewBottomAccessory {
    MiniPlayerView()
}
.tabBarMinimizeBehavior(.onScrollDown)
```

## Toolbars: `.toolbar` and `ToolbarItem` placements

Populate `.toolbar { }` with the current screen's most relevant actions, using placements that match iOS conventions: `.topBarLeading` and `.topBarTrailing` for navigation-bar actions, `.bottomBar` for a bottom action bar, and `.principal` to replace the title view itself (e.g., a segmented control). Don't place more than two or three icons on either side of the navigation bar — anything beyond that belongs in a `Menu`.

```swift
ContentView()
    .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isComposing = true
            } label: {
                Label("Compose", systemImage: "square.and.pencil")
            }
        }
        ToolbarItemGroup(placement: .bottomBar) {
            Button("Filter", systemImage: "line.3.horizontal.decrease.circle") {
                showFilters = true
            }
            Spacer()
            Button("Sort", systemImage: "arrow.up.arrow.down") {
                showSortOptions = true
            }
        }
    }
```

## Keep toolbar actions consistent across size classes

An action that appears in a screen's toolbar on iPhone should still be reachable in the same place on iPad — don't hide a `.topBarTrailing` button behind a size-class check unless there's a real reason the action doesn't apply. If a toolbar has too many actions for a compact width, collapse the overflow into a `Menu` rather than dropping actions silently.

```swift
ToolbarItem(placement: .topBarTrailing) {
    Menu {
        Button("Duplicate") { duplicate() }
        Button("Rename") { rename() }
        Button("Delete", role: .destructive) { delete() }
    } label: {
        Label("More", systemImage: "ellipsis.circle")
    }
}
```
