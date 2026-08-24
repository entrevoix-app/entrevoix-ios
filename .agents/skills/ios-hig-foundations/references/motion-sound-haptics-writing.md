# Motion, Sound, Haptics & Writing (iOS/iPadOS 26)

## Purposeful Motion

Animate to communicate a real change — a state transition, a spatial relationship (where a new view came from, where a dismissed one goes), or a direct response to a gesture — not to decorate an otherwise static screen. Prefer the implicit, system-tuned animations (`.animation(_:value:)`, `withAnimation(.default)`, `.spring()`) over long or elaborate custom curves; iOS interactions read as "native" when motion is quick, physically plausible, and interruptible.

```swift
withAnimation(.snappy) {
    isExpanded.toggle()
}
```

Interactive transitions (drag-to-dismiss a sheet, swipe-to-delete) should track the user's finger in real time rather than only animating after the gesture ends.

## Respecting Reduce Motion

Read `@Environment(\.accessibilityReduceMotion)` and provide a reduced alternative for any animation that is large, parallax-based, or purely decorative (zooming backgrounds, bouncing/spring overshoot, auto-playing motion). A crossfade or an instant state change is an acceptable substitute — do not simply disable the transition and leave a jarring visual pop.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring()) {
    isExpanded.toggle()
}
```

Never build essential information delivery on motion alone (e.g., a value that only appears mid-animation); Reduce Motion users, and anyone who interrupts the animation, must still get the information.

## Sound

Use system sounds (via `AudioServicesPlaySystemSound` for short system-style cues, or standard system alert/notification sounds) for standard events like completions, errors, and notifications rather than composing custom audio for things the system already has a convention for. Keep any custom sound short, subtle, and consistent with the action's importance; respect the ring/silent switch and system volume, and never play sound as the sole channel for critical information — pair it with a visual and, where relevant, a haptic.

## Haptics

Use haptic feedback to reinforce a discrete, meaningful action the user just took — a successful action, a warning, a selection change, a snapping/locking point — not on every tap or scroll increment, which quickly feels noisy and drains the "feedback" convention of meaning. In SwiftUI, prefer the `.sensoryFeedback(_:trigger:)` modifier; fall back to `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`, or `UISelectionFeedbackGenerator` directly in UIKit-backed code.

```swift
Button("Save") { save() }
    .sensoryFeedback(.success, trigger: didSave)
```

Match the feedback style to the semantics: `.impact(weight:)` for physical collisions/snaps, `.selection` for picker/segmented changes, `.success`/`.warning`/`.error` for outcome feedback — do not use `.error` haptics for a routine, expected action.

## Writing & Microcopy

Use sentence case for titles, buttons, and most UI text ("Turn on Notifications", not "Turn On Notifications" or "TURN ON NOTIFICATIONS"); reserve all-caps for the rare system-styled label that explicitly calls for it. Keep button and menu item labels short, verb-led, and specific about the action's outcome ("Delete Conversation" rather than "OK" or "Delete", when the destructive action needs disambiguation). Use terminology consistently with the rest of iOS — "Settings" not "Preferences", "Cancel" not "Dismiss" for abandoning an in-progress action — and avoid internal engineering jargon, error codes, or stack traces in user-facing copy; describe the problem and, where possible, the next step.

## Localizing and Reviewing Copy

Write copy that translates cleanly: avoid idioms, avoid packing multiple sentences into a button label, and keep interpolated values (names, counts) at the edges of a sentence rather than mid-clause, since word order varies by language. Run a final pass specifically for tone — iOS copy is generally calm and helpful rather than alarming or cute; reserve exclamation points and urgent phrasing for genuinely urgent situations (data loss, security).

## Privacy by Design

Default every screen to showing the least sensitive information necessary — mask account numbers, addresses, or health data behind a reveal action rather than always-on display, and request system permissions (camera, location, contacts, notifications) only at the moment their feature is used, with a clear, specific usage-description string explaining why. Prefer Apple's privacy-preserving system UI (e.g., the system photo/contact pickers, Sign in with Apple) over building custom flows that request broader access than the feature needs; this is a UI-surface check, not a substitute for a full data-handling/architecture review.

## Quick Checklist

Before treating a motion/sound/haptic/writing decision as done: the animation reflects a real change and has a Reduce-Motion-aware fallback; any sound or haptic reinforces a meaningful, discrete action rather than firing on every interaction; and all new UI copy uses sentence case, iOS terminology, and plain language a first-time user would understand.
