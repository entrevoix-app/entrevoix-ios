# Apple Pencil, Pointer/Trackpad, and Biometric Authentication on iPad

Guidance for Apple Pencil, pointer/trackpad, keyboard shortcuts, and Face ID/Touch ID on iOS/iPadOS 26.

## When Apple Pencil support is worth adding

Add Pencil-specific behavior when it meaningfully improves the task — freeform drawing, markup/annotation, sketching, precise selection, or handwriting — not as a checkbox feature. Whatever the app does with the Pencil, make sure the same action also works with a finger; Apple's review guidelines and the HIG both expect apps to remain fully usable by touch alone.

## Drawing and marking up with PencilKit

Wrap `PKCanvasView` for freeform drawing or annotation, and default `drawingPolicy` to `.anyInput` so a finger can draw too — reserve `.pencilOnly` for apps where finger-drawing would actively hurt the result (precision illustration tools):

```swift
struct CanvasContainer: UIViewRepresentable {
    let canvasView = PKCanvasView()

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 5)
        canvasView.drawingPolicy = .anyInput
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
```

Show `PKToolPicker` rather than building a custom tool palette — it already matches the system's pen/highlighter/eraser conventions and floats correctly alongside the Pencil.

## Hover preview

iPadOS shows a preview of where a mark will land while the Pencil hovers just above the glass, before it touches down. `PKCanvasView` provides this automatically for its own tools; if you build custom hover feedback for a non-PencilKit surface, use `UIHoverGestureRecognizer` and keep the preview lightweight (an outline or cursor, not new content) since it has no equivalent on a finger-only touch:

```swift
let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover))
view.addGestureRecognizer(hover)
```

## Pencil double-tap and squeeze gestures

Use `UIPencilInteraction` to react to a double-tap or (on Pencil Pro) a squeeze, but respect the user's system-wide preferred action rather than hardcoding your own mapping — read `UIPencilInteraction.preferredTapAction` and honor it:

```swift
let pencilInteraction = UIPencilInteraction()
pencilInteraction.delegate = self
view.addInteraction(pencilInteraction)

func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
    switch UIPencilInteraction.preferredTapAction {
    case .switchEraser: toggleEraser()
    case .switchPrevious: switchToPreviousTool()
    default: break
    }
}
```

Treat double-tap/squeeze as a shortcut to something already reachable in the tool palette — never the only way to switch tools.

## Scribble and handwriting input

Any standard `TextField` or `UITextField` supports Scribble — writing directly into the field with the Pencil — with no extra code. Don't disable it by intercepting Pencil touches on top of a text field; if you need custom Pencil handling there, make sure typed and Scribble input both still reach the field.

## Pointer and trackpad support on iPad

With iPadOS 26's full pointer support and menu bar, design as if a trackpad or mouse might drive the whole app. Add `.hoverEffect` to custom tappable views (not already a `Button`) so the system pointer highlights them on hover:

```swift
Text(item.title)
    .padding(8)
    .background(.tertiary, in: .rect(cornerRadius: 8))
    .hoverEffect(.highlight)
```

Prefer standard controls (`Button`, `Toggle`, list rows) over custom-drawn tappable shapes where possible — they already get correct pointer, hover, and click behavior without `.hoverEffect`.

## Right-click / secondary click via context menu

`.contextMenu` already responds to a long press on touch and to a right-click or two-finger tap on a trackpad — don't write separate pointer-specific logic for the same menu:

```swift
RowView(item: item)
    .contextMenu {
        Button("Rename") { rename(item) }
        Button("Delete", role: .destructive) { delete(item) }
    }
```

## Keyboard shortcuts and the iPadOS 26 menu bar

`.keyboardShortcut()` surfaces automatically in iPadOS 26's macOS-style menu bar, so external-keyboard shortcuts are far more discoverable than before — assign them to an app's frequent or destructive commands the same way you would on Mac:

```swift
Button("New Note") { createNote() }
    .keyboardShortcut("n", modifiers: .command)

Button("Delete", role: .destructive) { delete() }
    .keyboardShortcut(.delete, modifiers: .command)
```

Before assigning one, check it isn't already claimed system-wide (⌘Space Spotlight, ⌘Tab App Switcher, ⌘H Home) or by the menu bar's own standard items (⌘, Settings, ⌘W close window) — pick a nearby unused combination instead of overriding a reserved shortcut.

## Face ID / Touch ID authentication

Use `LocalAuthentication` to gate sensitive content or actions, and prefer the `.deviceOwnerAuthentication` policy so the system automatically offers the device passcode as a fallback when biometrics fail, aren't enrolled, or are disabled:

```swift
import LocalAuthentication

let context = LAContext()
var error: NSError?

if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
    context.evaluatePolicy(
        .deviceOwnerAuthentication,
        localizedReason: "Unlock your saved cards"
    ) { success, evaluationError in
        // Handle success/failure on the main actor.
    }
} else {
    // Biometrics unavailable — present your own passcode/passphrase entry.
}
```

Only reach for `.deviceOwnerAuthenticationWithBiometrics` (no automatic passcode fallback) if you build and present your own fallback UI immediately after a failure — never leave a user with no way in.

## When to require biometrics vs. skip it

Reserve a Face ID/Touch ID prompt for genuinely sensitive moments — viewing saved payment details, unlocking a private section, confirming a money transfer — not routine app launch, which just adds friction. Never make biometric authentication the sole gate on an app or feature; there must always be a passcode or passphrase path for a locked-out or non-enrolled user.
