# Sheets, Popovers, Action Sheets, Alerts, and Page Controls (iOS/iPadOS 26)

## Sheets for focused, single tasks

Use `.sheet(isPresented:)` (or the item-based `.sheet(item:)`) when the user needs to complete or explicitly cancel one focused task before returning — composing a message, configuring a new item, picking from a long list. A sheet is modal to the presenting view; give it clear confirm/cancel actions in its own toolbar rather than relying on a swipe-to-dismiss as the only way out for anything that isn't safely discardable.

```swift
struct InboxView: View {
    @State private var isComposing = false

    var body: some View {
        List(messages) { message in
            MessageRow(message: message)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Compose", systemImage: "square.and.pencil") {
                    isComposing = true
                }
            }
        }
        .sheet(isPresented: $isComposing) {
            ComposeView()
        }
    }
}
```

Don't stack a second `.sheet` on top of a presented sheet — present it from the first sheet's own view hierarchy instead, and keep the chain no deeper than one sheet presenting one more sheet.

## Partial-height sheets with `.presentationDetents`

Use `.presentationDetents` when the sheet's content doesn't need the full screen — a quick options picker, a share-style panel, a compact form. `.medium` and `.large` are the standard detents; a custom fraction or fixed height is for content with a genuinely fixed natural size.

```swift
.sheet(isPresented: $showFilters) {
    FilterOptionsView()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
```

Show the drag indicator (`.presentationDragIndicator(.visible)`) whenever the sheet supports multiple detents, so users discover they can resize it. For a sheet that should only ever show at one partial height, use a single detent rather than letting it default to `.large`:

```swift
.sheet(isPresented: $showQuickActions) {
    QuickActionsView()
        .presentationDetents([.height(220)])
}
```

## Popovers on iPad and Mac Catalyst

Use `.popover(isPresented:)` for lightweight, contextual content anchored to a specific control — a color swatch, an info bubble, a small options flyout from a toolbar button. On iPad and Mac Catalyst this renders as a true anchored popover with an arrow; on iPhone's compact width SwiftUI adapts it to a sheet-like presentation automatically, so a popover trigger still works everywhere without extra branching.

```swift
struct ColorSwatchButton: View {
    @State private var showPicker = false
    @Binding var color: Color

    var body: some View {
        Button {
            showPicker = true
        } label: {
            Circle().fill(color).frame(width: 24, height: 24)
        }
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            ColorPicker("Color", selection: $color)
                .padding()
                .frame(width: 240)
        }
    }
}
```

If the compact-width fallback presentation should look different from the default (e.g., forcing a small sheet instead of full-height), control it explicitly with `.presentationCompactAdaptation(.sheet)` (or `.popover`, `.none`) rather than leaving the default and then fighting it with custom detents.

```swift
.popover(isPresented: $showPicker) {
    ColorPicker("Color", selection: $color)
        .padding()
}
.presentationCompactAdaptation(.popover)
```

## Confirmation dialogs (the action sheet replacement)

Use `.confirmationDialog` — not a manually built `.sheet` of buttons — whenever the user needs to choose among a small set of actions related to one decision, especially before a destructive action. It supports a title, an optional message, and buttons with roles.

```swift
.confirmationDialog(
    "Delete Conversation?",
    isPresented: $showDeleteConfirmation,
    titleVisibility: .visible
) {
    Button("Delete", role: .destructive) {
        deleteConversation()
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("This cannot be undone.")
}
```

Always give a destructive confirmation dialog a `.destructive` role button and a `.cancel` role button; don't rely on button order or wording alone to signal severity.

## Alerts for critical information or a binary choice

Use `.alert` only for something the user must acknowledge or decide on right now — an unrecoverable error, a required confirmation with no other actions available. Keep the title short and put explanatory detail in the message; keep alerts to one or two buttons.

```swift
.alert("Couldn't Save Draft", isPresented: $showSaveError) {
    Button("OK", role: .cancel) {}
} message: {
    Text("Check your connection and try again.")
}
```

Don't use `.alert` for routine informational messages or anything with more than two or three choices — that's a `.confirmationDialog` or a sheet instead.

## Page controls: paged `TabView`

Use `TabView` with `.tabViewStyle(.page)` for a small set of peer screens the user swipes through horizontally — onboarding steps, a photo carousel, a set of feature highlights — where the dot indicator communicates position and count.

```swift
struct OnboardingView: View {
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            OnboardingStepView(step: .welcome).tag(0)
            OnboardingStepView(step: .permissions).tag(1)
            OnboardingStepView(step: .finish).tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}
```

Keep paged `TabView` content to a handful of screens (roughly under 6–8) — beyond that the dot indicator stops being a useful position cue, and a `List`/`NavigationStack` flow or a `NavigationSplitView` on iPad is the better structure.
