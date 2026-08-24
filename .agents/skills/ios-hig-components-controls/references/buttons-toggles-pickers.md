# Buttons, Toggles, Pickers, Segmented Controls, Sliders, Steppers, Labels

## Button styles and roles

Pick a `Button` style by how important the action is on screen, not by
personal preference. iOS 26 renders these with Liquid Glass materials —
`.borderedProminent` gets a solid glass-tinted fill, `.bordered` gets a
lighter glass outline, `.plain` stays borderless (text/icon color only).
Use one `.borderedProminent` button per screen or sheet for the primary
action; everything else should be `.bordered` or `.plain`. Use `role: .destructive`
for irreversible actions so the system applies the destructive (red) tint
automatically instead of hardcoding a color.

```swift
VStack(spacing: 12) {
    Button("Save Changes") { save() }
        .buttonStyle(.borderedProminent)

    Button("Cancel") { dismiss() }
        .buttonStyle(.bordered)

    Button("Delete Account", role: .destructive) { deleteAccount() }
        .buttonStyle(.bordered)
}
```

For toolbar and navigation-bar buttons, prefer icon-only `Button`s with a
system symbol and let the system apply the glass "capsule" treatment; don't
wrap every toolbar button in `.borderedProminent`, which competes with the
one primary action.

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button("Add", systemImage: "plus") { addItem() }
    }
}
```

## Minimum tap targets

Every interactive control must have a hit area of at least 44x44pt,
regardless of how small its visible glyph is. If a button's label is a
small icon, pad it out rather than shrinking the frame below 44pt.

```swift
Button {
    toggleFavorite()
} label: {
    Image(systemName: "star")
        .frame(width: 44, height: 44)
}
```

## Toggle — switch, not checkbox

iOS defaults to the switch-style `Toggle`; the `.checkbox` toggle style is a
macOS idiom and should not be used on iOS/iPadOS. Give every toggle a clear,
short label describing the state it controls, and bind it straight to a
`Bool`.

```swift
Toggle("Enable Notifications", isOn: $notificationsEnabled)
```

Use `.toggleStyle(.switch)` only if you need to force the style inside a
container that would otherwise infer something else (e.g., inside a `Menu`).

## Pickers — wheel, menu, segmented

Use a segmented `Picker` for 2–5 mutually exclusive, short-label options
that should all be visible at once (view filters, unit switches). Use a
menu-style `Picker` (the default in a `Form`/`List` row) when there are more
options than comfortably fit a segmented control. Reserve the wheel style
for compact, high-precision selection (time, quantity) where scrubbing beats
tapping.

```swift
Picker("Sort", selection: $sortOrder) {
    Text("Newest").tag(SortOrder.newest)
    Text("Oldest").tag(SortOrder.oldest)
    Text("A–Z").tag(SortOrder.alphabetical)
}
.pickerStyle(.segmented)
```

```swift
Picker("Country", selection: $country) {
    ForEach(Country.allCases) { country in
        Text(country.name).tag(country)
    }
}
.pickerStyle(.menu)
```

## DatePicker

Use the compact style inside forms/rows and the graphical (calendar) style
when the user benefits from seeing a full month at once. Constrain the
range with `in:` rather than validating after the fact.

```swift
DatePicker(
    "Appointment",
    selection: $appointmentDate,
    in: Date()...,
    displayedComponents: [.date, .hourAndMinute]
)
```

## Slider and Stepper

Use `Slider` for continuous, approximate values where the exact number
matters less than the relative position (volume, brightness). Use `Stepper`
for discrete values a user needs to land on precisely (quantity, servings).
Always show the current value as text next to a `Slider` — the control
alone doesn't communicate the number.

```swift
VStack(alignment: .leading) {
    Text("Volume: \(Int(volume * 100))%")
    Slider(value: $volume, in: 0...1)
}

Stepper("Servings: \(servings)", value: $servings, in: 1...12)
```

## Label — icon + text conventions

Use `Label` (not a manual `HStack` of `Image` + `Text`) so icon and title
stay aligned and get Dynamic Type/VoiceOver behavior for free. Keep the
system symbol semantically matched to the text; don't decorate with icons
that don't map to the action.

```swift
Label("Settings", systemImage: "gearshape")
Label("Delete", systemImage: "trash")
    .foregroundStyle(.red)
```
