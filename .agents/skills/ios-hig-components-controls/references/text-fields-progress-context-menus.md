# Text Fields, Text Views, Progress Indicators, Context Menus

## TextField basics

Give every `TextField` a real label (its first argument) even if you visually
hide it, so VoiceOver and Dynamic Type still work. Set the right keyboard
type for the data being entered — don't leave everything on the default
alphabetic keyboard.

```swift
TextField("Email", text: $email)
    .keyboardType(.emailAddress)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()

TextField("Phone Number", text: $phone)
    .keyboardType(.phonePad)
```

Match `.textInputAutocapitalization` to the content: `.never` for
emails/usernames/URLs, `.words` for names, `.sentences` (the default) for
free-form prose. Don't leave autocapitalization on `.sentences` for a field
that expects a lowercase identifier.

## SecureField

Use `SecureField` for passwords and other sensitive one-line entry — it
masks input and integrates with the system's password AutoFill and Strong
Password suggestions. Pair it with a "Show password" toggle only if the
product explicitly needs one; don't build custom masking on top of a plain
`TextField`.

```swift
SecureField("Password", text: $password)
    .textContentType(.password)
```

## TextEditor for multi-line input

Use `TextEditor` for free-form, multi-line text (notes, comments, bios);
`TextField` with `axis: .vertical` is a lighter-weight alternative when you
want a growing single-to-few-line field inside a form row rather than a
dedicated editing surface.

```swift
TextEditor(text: $notes)
    .frame(minHeight: 120)

TextField("Notes", text: $shortNote, axis: .vertical)
    .lineLimit(1...4)
```

## Focus and keyboard dismissal

Bind a `@FocusState` when you need to move focus between fields or dismiss
the keyboard programmatically (e.g., a "Done" toolbar button), rather than
reaching for UIKit responder APIs.

```swift
@FocusState private var focusedField: Field?

TextField("Email", text: $email)
    .focused($focusedField, equals: .email)
    .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { focusedField = nil }
        }
    }
```

## Progress indicators

Use a determinate `ProgressView` (with a `value`) whenever you can compute
real progress — file uploads, multi-step onboarding — so the user has an
accurate expectation of remaining time. Use the indeterminate spinner form
only when duration is genuinely unknown (a network call of unpredictable
length). Don't show a spinner forever with no timeout or cancel path.

```swift
ProgressView(value: uploadProgress) {
    Text("Uploading…")
}

ProgressView("Loading…")
```

Pull-to-refresh spinners are supplied automatically by `.refreshable` on a
`List` or `ScrollView` — don't layer a second `ProgressView` on top of that
gesture; see `references/lists-tables-swipe-actions.md` for `.refreshable`.

## Context menus

Attach `.contextMenu` to a row, card, or any tappable item that has
secondary actions which don't need to be visible all the time — the same
kind of action set you'd otherwise put behind a swipe action or an overflow
button. Order items by frequency of use, put destructive actions last with
`role: .destructive`, and keep the menu to a handful of items; a long-press
menu that requires scrolling has too many actions.

```swift
Text(photo.title)
    .contextMenu {
        Button {
            share(photo)
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        Button {
            duplicate(photo)
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        Button(role: .destructive) {
            delete(photo)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
```

## Context menu previews

Add a `preview:` closure to show a larger representation of the item during
the long-press before the menu appears — useful for images, cards, or list
rows whose content is truncated. Keep the preview view lightweight; it's
rendered live during the gesture.

```swift
Text(photo.title)
    .contextMenu {
        Button("Share", systemImage: "square.and.arrow.up") { share(photo) }
    } preview: {
        PhotoThumbnail(photo: photo)
            .frame(width: 200, height: 200)
    }
```

Don't put a context menu's only actions behind a gesture with no visible
equivalent anywhere else in the UI unless the action set is genuinely
secondary — critical actions still need a discoverable, always-visible
control (a button or swipe action).
