# Lists, Tables, Sections, Swipe Actions, Pull-to-Refresh

## List as the default scrolling container

Use `List` for any single-column, scrollable collection of rows — settings
screens, feeds, search results. Don't build a scrolling stack of rows by
hand with `ScrollView` + `VStack`; `List` gives you cell separators,
section headers, swipe actions, and accessibility rotor support for free.

```swift
List(items) { item in
    Text(item.title)
}
```

## Sections

Group related rows under a `Section` with a short header, and use a footer
only for a brief clarifying note (not for actions). Section headers should
read as category labels, not sentences.

```swift
List {
    Section("Account") {
        Text("Profile")
        Text("Privacy")
    }
    Section("Notifications") {
        Toggle("Push Notifications", isOn: $pushEnabled)
    }
}
.listStyle(.insetGrouped)
```

## Row content

Keep row text succinct — truncated titles are hard to scan. Use a leading
`Label` or icon plus a left-aligned title as the default row shape; add a
trailing value or `Text` in a muted color for a value-style row instead of
inventing a custom layout.

```swift
ForEach(contacts) { contact in
    HStack {
        Label(contact.name, systemImage: "person.crop.circle")
        Spacer()
        Text(contact.phone)
            .foregroundStyle(.secondary)
    }
}
```

## Swipe actions

Use `.swipeActions` for row-scoped actions that don't need to be visible
all the time (delete, archive, flag). Put the most likely destructive
action (delete) with `role: .destructive` so iOS colors and positions it
correctly, and keep the total action count per edge to two or three —
more than that and users can't distinguish them by muscle memory alone.
Leading-edge actions are for lower-frequency or non-destructive actions;
trailing-edge is the default location users expect for delete.

```swift
List {
    ForEach(messages) { message in
        Text(message.subject)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    delete(message)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    toggleRead(message)
                } label: {
                    Label("Read", systemImage: "envelope.open")
                }
                .tint(.blue)
            }
    }
}
```

Don't duplicate a swipe action as a separate always-visible button in the
same row unless the action is critical enough to need discoverability
without swiping — pick one placement, not both.

## Pull-to-refresh

Attach `.refreshable` directly to the `List` (not a wrapping view) whenever
new data can be fetched, and make the closure `async`. The system supplies
the spinner and haptic; don't add a second custom loading indicator on top
of it.

```swift
List(articles) { article in
    Text(article.headline)
}
.refreshable {
    await loadLatestArticles()
}
```

## Editing and reordering

Use the built-in edit affordances (`.onDelete`, `.onMove` inside
`EditButton`/`.editMode`) rather than custom drag handles, so behavior
matches system apps like Mail and Reminders.

```swift
List {
    ForEach(tasks) { task in
        Text(task.title)
    }
    .onDelete { indexSet in tasks.remove(atOffsets: indexSet) }
    .onMove { indices, newOffset in tasks.move(fromOffsets: indices, toOffset: newOffset) }
}
.toolbar { EditButton() }
```

## Loading and empty states

Show textual content as soon as it's available and let images load in
progressively; use a `ProgressView` only while there's truly nothing to
show yet, and use `ContentUnavailableView` for a genuinely empty list
instead of leaving a blank `List`.

```swift
if items.isEmpty {
    ContentUnavailableView(
        "No Items",
        systemImage: "tray",
        description: Text("Items you add will appear here.")
    )
} else {
    List(items) { item in
        Text(item.title)
    }
}
```
