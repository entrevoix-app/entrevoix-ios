# Entering Data, Feedback, Launching, and Loading

## Form structure and field grouping

Group related fields into sections (`Form` + `Section` in SwiftUI) so a small model can scan structure without parsing free-floating `TextField`s. Order fields the way a person would say them out loud (name before email before address), and keep one logical task per screen rather than one giant form.

```swift
Form {
    Section("Contact") {
        TextField("Name", text: $name)
        TextField("Email", text: $email)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
    }
}
```

## Keyboard types and content types

Always set `.keyboardType` and `.textContentType` (or `.textInputAutocapitalization`) to match the data — `.emailAddress`, `.phonePad`, `.numberPad`, `.URL`, `.oneTimeCode` — so the system offers the right keyboard layout and QuickType suggestions. Never ask for data iOS already knows through Autofill (passwords, addresses, payment cards, one-time codes); wire `.textContentType(.password)`, `.newPassword`, or `.creditCardNumber` instead of building a custom capture flow.

```swift
SecureField("Password", text: $password)
    .textContentType(.password)
TextField("One-Time Code", text: $otp)
    .textContentType(.oneTimeCode)
    .keyboardType(.numberPad)
```

## Inline validation timing

Validate as the person leaves a field or pauses typing, not on every keystroke, and never block submission with a modal alert for a single-field error — show inline text under the field instead. Reserve the submit-time check for cross-field or server-side validation that could not be known earlier, and keep the error message specific enough to name what to fix.

```swift
TextField("Email", text: $email)
    .onChange(of: focusedField) { _, newValue in
        if newValue != .email { emailError = validate(email) }
    }
if let emailError { Text(emailError).font(.footnote).foregroundStyle(.red) }
```

## Matching feedback to severity

Pick the feedback surface by how much attention the situation deserves, not by habit: a destructive or blocking decision needs an `alert`; a single field problem needs inline text; a transient, non-blocking status (saved, sent, undo available) needs a toast/banner that dismisses itself; an ongoing operation needs a progress indicator. Never use an alert for something the person can safely ignore, and never use a silent toast for something that loses data if missed.

```swift
.alert("Delete Project?", isPresented: $showDelete) {
    Button("Delete", role: .destructive) { delete() }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("This cannot be undone.")
}
```

## Toasts, banners, and inline status

Toasts/banners are for information the person doesn't need to act on immediately — keep them brief, auto-dismiss them, and never stack more than one at a time. Prefer an inline status view tied to the control that triggered the action (a checkmark next to a Save button) over a floating banner when the source of the change is visible on screen.

## Progress indicators

Use an indeterminate `ProgressView` for waits with no known duration and a determinate one (with a fraction) once you can estimate progress; switch between the two rather than faking a determinate bar. For operations under roughly a second, skip the indicator entirely — it reads as flicker, not feedback.

```swift
ProgressView(value: progress) // determinate
ProgressView("Loading…")      // indeterminate
```

## Loading states and perceived performance

Show a skeleton (placeholder shapes matching the eventual layout) for content that is structured and about to populate, instead of a centered spinner, so the layout doesn't jump when data arrives. Use `.redacted(reason: .placeholder)` for a quick skeleton effect on real view hierarchies you already have.

```swift
List(items.isEmpty ? placeholderItems : items) { item in
    ItemRow(item: item)
}
.redacted(reason: items.isEmpty ? .placeholder : [])
```

## Fast launch

Get to interactive content before fetching anything non-essential: render cached or last-known state immediately, then refresh in the background. Never show a branded launch/splash screen longer than the system's own launch-screen transition — it should read as instant, not as an intro animation.

## State restoration

Persist and restore navigation position, scroll offset, and in-progress input (draft text, selected tab) across relaunches and, on iPad, across window/Stage Manager swaps, using `NavigationPath`/`@SceneStorage` or `UIStateRestoration` in UIKit. Losing a half-typed form because the app was suspended is a launching failure, not an edge case — restore it rather than resetting to a blank screen.

```swift
@SceneStorage("selectedTab") private var selectedTab: Int = 0
```

## Combining patterns without over-building

A single flow rarely needs more than one feedback surface at a time — a form submission that fails should show inline field errors plus, if the failure was a network problem rather than a field problem, a single banner, not both an alert and a banner and a toast. When in doubt, pick the least interruptive surface that still gets the necessary information across, and confirm the simpler choice actually works before layering on anything else.
