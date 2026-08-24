# Layout, Color & Materials (iOS/iPadOS 26)

## Safe Areas First

Never place interactive or critical content outside the safe area — under the Dynamic Island/notch, behind the status bar, or under the home indicator. Let SwiftUI's default layout do this for you; only opt out with `.ignoresSafeArea()` for decorative backgrounds (images, gradients, color washes) that should bleed to the edges, and even then keep foreground content inside the safe area with `.safeAreaInset(edge:)` or ordinary padding.

```swift
ZStack {
    Image("hero").resizable().ignoresSafeArea() // background only
    VStack { Text("Title") } // stays inside the safe area
}
```

## Avoiding the Dynamic Island and Notch

Treat the Dynamic Island like the notch it replaced: it is a hardware exclusion zone, not just a visual shape. Do not draw custom chrome that assumes a fixed top-bar height across devices — use safe area insets and `GeometryReader`/`ContainerRelativeShape` sparingly, only when a system layout container does not already solve the problem. Full-screen media should size around the safe area rather than clipping content behind the island.

## Margins, Alignment & Spacing

Use consistent margins (typically 16–20pt on iPhone, wider on iPad) and align related content on a shared leading edge; avoid ad hoc one-off insets scattered across views. Prefer system spacing (`.padding()` with no argument, `Spacer()`, `VStack(spacing:)`) over magic-number constants so spacing scales sensibly with Dynamic Type and size class. Group related controls tightly and separate unrelated groups with clearly larger gaps rather than uniform spacing everywhere.

```swift
VStack(alignment: .leading, spacing: 12) {
    Text("Section title").font(.headline)
    Text("Supporting detail").font(.subheadline).foregroundStyle(.secondary)
}
.padding()
```

## Size Classes & iPad Adaptivity

Read `@Environment(\.horizontalSizeClass)` and `@Environment(\.verticalSizeClass)` to adapt layout rather than checking device idiom directly — the same iPad can be `.compact` in Split View or Slide Over. Use `ViewThatFits` for layouts that should reflow between a compact and regular arrangement, and reserve multi-column/sidebar structures (which belong to navigation structure, not this skill) for regular-width environments. Design touch targets and text at sizes that work when an iPad app runs at `.compact` width just as an iPhone would.

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

var body: some View {
    if horizontalSizeClass == .compact {
        CompactSummaryView()
    } else {
        DetailedSummaryView()
    }
}
```

## System and Semantic Colors

Always reach for semantic colors before literal ones: `.primary`/`.secondary` for text, `Color(.systemBackground)`, `Color(.secondarySystemBackground)`, `Color(.systemGroupedBackground)` for surfaces, and `Color(.separator)` for dividers. These automatically adapt to Dark Mode, increased-contrast, and Liquid Glass tinting; a hardcoded `Color(red:green:blue:)` does none of that and will look wrong in at least one mode.

```swift
Text("Balance").foregroundStyle(.primary)
Text("Updated 2m ago").foregroundStyle(.secondary)
Rectangle().fill(Color(.secondarySystemBackground))
```

## Accent Color & Tinting

Set one app-wide accent color (Assets catalog "AccentColor" or `.tint()`) and let controls inherit it rather than hardcoding tint per-control; this keeps buttons, toggles, and selection indicators visually consistent and lets the system apply accent-aware Liquid Glass tinting correctly. Use `.tint(_:)` locally only to intentionally differentiate a specific control (e.g., a destructive action in red), not as the default styling mechanism.

```swift
Button("Continue") { }.tint(.accentColor) // usually just inherit; be explicit only to override
```

## Dark Mode

Support Dark Mode by construction, not as an afterthought: use semantic colors and asset-catalog color sets with "Any, Dark" (and "Any, Dark, High Contrast" where relevant) variants instead of branching on `@Environment(\.colorScheme)` to pick literal colors. Avoid pure black (`#000000`) backgrounds and pure white text at full opacity — Apple's system dark surfaces use dark grays, and pure black can cause smearing on OLED and clipped highlights in Liquid Glass materials. Always preview and test both appearances before shipping a screen.

## Liquid Glass Materials

Liquid Glass is the iOS 26 material system for controls and surfaces that float above content — navigation bars, tab bars, toolbars, sheets, floating buttons — giving them a translucent, dynamic, light-reactive appearance rather than a flat fill. Apply it with the `.glassEffect(_:in:)` modifier (default `.regular` glass, or `.clear` for more transparent contexts) inside a `GlassEffectContainer` when multiple glass shapes need to interact or morph together, and use `glassEffectID` to animate elements merging or splitting.

```swift
GlassEffectContainer(spacing: 16) {
    HStack(spacing: 16) {
        Button("Reply", systemImage: "arrowshape.turn.up.left") { }
            .glassEffect(.regular, in: .capsule)
        Button("Delete", systemImage: "trash") { }
            .glassEffect(.regular.tint(.red), in: .capsule)
    }
}
```

## Avoiding Overuse of Glass

Reserve Liquid Glass for the floating control layer; do not apply `.glassEffect` to ordinary content views, full-screen backgrounds, or large blocks of text and images — glass over glass or glass over busy scrolling content reduces legibility and defeats the depth effect Apple intends. Where a surface is not meant to float (a static card, a settings row, a static list background), use a plain semantic background color instead. Many system components (navigation bar, tab bar, sheets, alerts, `.searchable()`) already adopt Liquid Glass automatically in iOS 26 — do not re-wrap them in an additional manual glass effect.

## Glass and Accessibility Settings

Reduced Transparency and Increased Contrast (Settings > Accessibility > Display & Text Size) automatically make the system flatten or darken Liquid Glass materials — code that uses `.glassEffect` and semantic colors gets this for free and needs no extra branching. Do not fight the system by forcing full opacity or a custom high-contrast style on top of glass; if a design genuinely requires a non-glass fallback for a specific reason, read `@Environment(\.accessibilityReduceTransparency)` and swap to a solid semantic background rather than a lower-contrast custom material.

## Alignment Between Size Classes

When a layout adapts between compact and regular width, keep the same content alignment and reading order in both — a leading-aligned title in compact width should still be leading-aligned in regular width, just with more breathing room or an added column, not re-centered or reordered. Test rotation and Split View/Slide Over resizing on iPad explicitly; a layout that only assumes full-screen regular width breaks the moment the user drags the multitasking divider.

## GeometryReader Caution

Reach for `GeometryReader` only when no built-in layout container (`VStack`, `HStack`, `Grid`, `ViewThatFits`, alignment guides) can express the layout, since it opts a subtree out of SwiftUI's normal sizing negotiation and commonly causes it to greedily fill available space. Prefer `.containerRelativeFrame(_:)` or alignment guides for proportional sizing tied to a container, and reserve `GeometryReader` for genuinely custom, size-dependent drawing.

## Quick Checklist

Before treating a layout/color/material decision as done: content stays inside the safe area on every device size; the layout reads correctly at both compact and regular width; colors are semantic, not literal, and both appearances have been previewed; any `.glassEffect` sits on a floating control, not on base content; and Reduced Transparency/Increased Contrast have not been fought against.
