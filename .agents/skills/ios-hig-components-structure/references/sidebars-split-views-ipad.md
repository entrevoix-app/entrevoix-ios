# Sidebars and Split Views on iPad (iOS/iPadOS 26)

## NavigationSplitView adapts automatically between iPad and iPhone

Use `NavigationSplitView` for any app whose primary content is a list driving a detail view (mailboxes, folders, settings sections). On iPad/regular-width it renders as a sidebar plus detail; on iPhone/compact-width it automatically collapses to a single navigation stack, pushing the detail view when a row is selected. Don't write your own `UIScreen`/size-class branching to fake this — the collapse behavior is built in.

```swift
struct MailRootView: View {
    @State private var selectedMailbox: Mailbox.ID?

    var body: some View {
        NavigationSplitView {
            List(mailboxes, selection: $selectedMailbox) { mailbox in
                Label(mailbox.name, systemImage: mailbox.symbol)
            }
            .navigationTitle("Mailboxes")
        } detail: {
            if let selectedMailbox {
                MessageListView(mailboxID: selectedMailbox)
            } else {
                ContentUnavailableView("Select a Mailbox", systemImage: "tray")
            }
        }
    }
}
```

Always provide an explicit empty-state view in `detail` for when nothing is selected — on iPad that empty state is visible immediately at launch, unlike on iPhone where the sidebar is shown first.

## Three-column split views

Add a middle `content` column when the sidebar's selection drives a second list before reaching the real detail (mailbox → message list → message body). On iPhone this collapses to a three-level stack (sidebar, then content, then detail), pushed one at a time.

```swift
struct MailRootView: View {
    @State private var selectedMailbox: Mailbox.ID?
    @State private var selectedMessage: Message.ID?

    var body: some View {
        NavigationSplitView {
            List(mailboxes, selection: $selectedMailbox) { mailbox in
                Label(mailbox.name, systemImage: mailbox.symbol)
            }
        } content: {
            MessageListView(mailboxID: selectedMailbox, selection: $selectedMessage)
                .navigationSplitViewColumnWidth(min: 260, ideal: 320)
        } detail: {
            MessageDetailView(messageID: selectedMessage)
        }
    }
}
```

Don't nest a second `NavigationSplitView` inside the detail column for a fourth level of structure — if the detail needs more sub-navigation, push another screen with `NavigationStack` inside that column instead.

## Column visibility and the sidebar toggle

`NavigationSplitView` adds its own sidebar toggle to the toolbar automatically. Only introduce an explicit `NavigationSplitViewVisibility` binding when you need to programmatically show/hide/collapse a column (e.g., collapsing the sidebar after a selection on a compact iPad multitasking width) — don't add a second custom toggle button alongside the system one.

```swift
struct BrowserRootView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarList()
        } detail: {
            DetailView()
        }
    }
}
```

## Split view style

Use `.navigationSplitViewStyle(.balanced)` (the default) so the sidebar keeps a fixed proportion of the width as the window resizes — this is the right choice for nearly all sidebar apps, including iPad Split View multitasking. Reach for `.prominentDetail` only when the detail content should dominate and the sidebar/content columns should recede as overlays; don't pick it just to make the sidebar narrower.

```swift
NavigationSplitView {
    SidebarList()
} detail: {
    DetailView()
}
.navigationSplitViewStyle(.balanced)
```

## Column width constraints

Give the sidebar and any content column sane `min`/`ideal`/`max` widths so text doesn't clip on a narrower iPad (e.g., Slide Over or a smaller multitasking split) and doesn't stretch absurdly wide on a large iPad Pro display.

```swift
List(selection: $selection) {
    ForEach(sections) { section in
        Label(section.name, systemImage: section.symbol)
    }
}
.navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 320)
```

## TabView as a sidebar on iPad: `.sidebarAdaptable`

For an app whose top-level structure is a `TabView` of 5 or fewer destinations, `.tabViewStyle(.sidebarAdaptable)` lets the same declaration render as a bottom tab bar on iPhone and as a sidebar on iPad — without maintaining two separate navigation structures. Give each tab its own `NavigationStack` so the system has a navigation bar to attach the sidebar toggle to.

```swift
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack {
                    HomeView()
                }
            }
            Tab("Library", systemImage: "books.vertical") {
                NavigationStack {
                    LibraryView()
                }
            }
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack {
                    SearchView()
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
```

Choose between a plain `NavigationSplitView` sidebar and a `.sidebarAdaptable` `TabView` based on what the structure actually is: if the destinations are genuinely top-level app sections a user jumps between at any time, use `.sidebarAdaptable`; if it's a browsing list that drives a dependent detail (most content doesn't make sense without a selection), use `NavigationSplitView`. Don't run both patterns for the same set of destinations.

## What NOT to hand-build

Don't reimplement sidebar collapse, column proportions, or the sidebar toggle button with manual `HStack`/`GeometryReader` layout and a hand-tracked "is sidebar visible" `@State` — every one of those is exactly what `NavigationSplitView` already provides correctly across orientation changes, multitasking splits, and Stage Manager.
