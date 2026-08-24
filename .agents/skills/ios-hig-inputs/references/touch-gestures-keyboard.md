# Touch Gestures and the On-Screen Keyboard

Guidance for touchscreen gesture handling and on-screen keyboard behavior on iOS/iPadOS 26.

## Tap and double-tap

Tap performs a view's primary action; reserve double-tap for a secondary, non-destructive action (zoom, like) that doesn't hide a feature the user needs regularly, since double-tap is slower to discover than a single tap or a visible button:

```swift
Image("photo")
    .onTapGesture(count: 2) {
        toggleZoom()
    }
```

Don't attach both a single-tap and a double-tap handler to the same view unless the single-tap action still fires correctly — SwiftUI waits briefly to distinguish the two, which can make a single tap feel delayed.

## Long press for secondary actions

Prefer `.contextMenu` over a hand-rolled long-press handler when the goal is the standard "hold to preview and act" pattern — it gets the system's press-and-hold timing, preview, and haptic for free:

```swift
RowView(item: item)
    .contextMenu {
        Button("Favorite", systemImage: "star") { favorite(item) }
        Button("Delete", systemImage: "trash", role: .destructive) { delete(item) }
    }
```

Reach for `.onLongPressGesture` directly only for custom press-and-hold behavior a context menu can't express, such as starting a recording or arming a drag:

```swift
Circle()
    .onLongPressGesture(minimumDuration: 0.5) {
        startRecording()
    }
```

## Swipe and system-reserved edges

The system reserves several screen edges for its own gestures: the left/right edges for back navigation (inside a `NavigationStack`) and Slide Over/app switching on iPad, the top edge for Control Center and Notification Center, and the bottom edge for the Home indicator and App Switcher. Never attach a competing custom gesture to those edges — require a custom swipe to start away from the edge, or use a gesture shape (two-finger swipe, a specific direction inside content) the system doesn't already claim:

```swift
Rectangle()
    .gesture(
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                if value.translation.width < -50 { showNext() }
            }
    )
```

For list-row actions specifically, use `.swipeActions` (covered in ios-hig-components-controls) instead of rebuilding swipe-to-delete/swipe-to-archive with a raw `DragGesture`.

## Pinch to zoom

Support pinch wherever content can meaningfully scale — images, PDFs, maps, canvases — and pair it with the double-tap-to-zoom shortcut users expect from Photos and Safari:

```swift
Image("diagram")
    .scaleEffect(scale)
    .gesture(
        MagnifyGesture()
            .onChanged { value in scale = value.magnification }
    )
    .onTapGesture(count: 2) { scale = scale == 1 ? 2 : 1 }
```

Pinch itself isn't system-reserved, but don't repurpose it for anything other than scaling content — that mapping is what users expect everywhere it appears.

## Resolving gesture conflicts

When a custom gesture and a container's own gesture (a `ScrollView`'s scroll, a `NavigationStack`'s back-swipe) compete for the same touch, use `.simultaneousGesture` to let both run, or `.highPriorityGesture` only when the custom gesture must win outright:

```swift
ScrollView {
    content
}
.simultaneousGesture(
    DragGesture().onChanged { value in trackPreview(value) }
)
```

Test any custom gesture by dragging from the exact edge and inside the exact area the system gesture uses — a gesture that merely feels fine in the simulator can still swallow back-swipe on device.

## Discoverability: never gesture-only

Any action reachable only through a gesture that isn't a plain tap — a long press, a multi-finger swipe, a hidden edge drag — must also be reachable through a visible control (a button, toolbar item, or menu entry). Gestures aren't guessable, and Switch Control and other assistive input can't perform an arbitrary custom gesture.

## Choosing a keyboard type

Match `.keyboardType` and `.textContentType` to the data being entered so the system shows the right keys and offers autofill:

```swift
TextField("Email", text: $email)
    .keyboardType(.emailAddress)
    .textContentType(.emailAddress)
    .autocorrectionDisabled()

TextField("Amount", text: $amount)
    .keyboardType(.decimalPad)
```

Don't default every field to `.default` — a numeric field with the standard alphabetic keyboard forces users to hunt for a number row that isn't there.

## Submit labels and moving between fields

Set `.submitLabel` to describe what pressing Return actually does, and use `.onSubmit` with `@FocusState` to advance to the next field or trigger the action instead of leaving Return dead:

```swift
enum Field { case email, password }
@FocusState private var focusedField: Field?

TextField("Email", text: $email)
    .submitLabel(.next)
    .focused($focusedField, equals: .email)
    .onSubmit { focusedField = .password }

SecureField("Password", text: $password)
    .submitLabel(.done)
    .focused($focusedField, equals: .password)
    .onSubmit { signIn() }
```

## Keeping content visible while typing

Wrap text input in a `ScrollView` so SwiftUI scrolls the focused field above the keyboard automatically, rather than computing keyboard-avoidance offsets by hand:

```swift
ScrollView {
    VStack(spacing: 16) {
        TextField("Name", text: $name)
        TextField("Notes", text: $notes)
    }
    .padding()
}
.scrollDismissesKeyboard(.interactively)
```

If a fixed control (a bottom action bar) risks sitting under the keyboard, anchor it with `.safeAreaInset(edge: .bottom)` instead of a hardcoded offset — the inset already adjusts for the keyboard's height.

## Dismissing the keyboard deliberately

Let `.scrollDismissesKeyboard(.interactively)` handle dismissal via scroll, and give a visible way to dismiss otherwise (a "Done" toolbar button, or the field's own submit action) rather than forcing `resignFirstResponder` from an unrelated gesture. On iPad, the keyboard's own dismiss key is always available — don't hide or replace it.
