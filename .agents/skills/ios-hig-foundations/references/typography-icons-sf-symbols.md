# Typography, App Icons & SF Symbols (iOS/iPadOS 26)

## System Font & Text Styles

Default to the San Francisco system font via semantic text styles (`Font.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.body`, `.callout`, `.subheadline`, `.footnote`, `.caption`, `.caption2`) rather than fixed point sizes. Text styles carry the correct weight, leading, and tracking for their role and scale together as one system when the user changes their preferred text size — a literal `.system(size: 15)` does not.

```swift
Text("Order #4821").font(.headline)
Text("Delivered yesterday").font(.subheadline).foregroundStyle(.secondary)
```

## Dynamic Type Is Not Optional

Every piece of user-facing text must scale with the user's chosen text size, including at accessibility sizes. Avoid `.fixedSize()` and `.lineLimit(1)` on body text unless truncation is genuinely acceptable; test layouts at the largest accessibility sizes (Settings > Accessibility > Display & Text Size > Larger Text) so text does not clip or overlap. For custom fonts or fixed-size icons that must scale proportionally with type, use `@ScaledMetric` instead of a hardcoded constant.

```swift
@ScaledMetric private var iconSize: CGFloat = 24

Image(systemName: "bell.fill")
    .resizable()
    .frame(width: iconSize, height: iconSize)
```

Prefer layouts that reflow (e.g., stacking horizontal content vertically at large sizes) over ones that just clip; `ViewThatFits` and dynamic `VStack`/`HStack` switching handle this well.

## SF Symbols Basics

Use SF Symbols (`Image(systemName:)`) for icons instead of custom bitmap glyphs wherever a suitable symbol exists — they align to the text baseline, scale with Dynamic Type, and support the same weight and rendering options as the surrounding text. Match a symbol's weight to adjacent text with `.fontWeight(_:)` and its size with `.font(_:)` or `.imageScale(_:)` rather than resizing the frame directly.

```swift
Label("Favorites", systemImage: "star.fill")
    .font(.body)
    .fontWeight(.semibold)
```

## Rendering Modes

SF Symbols support four rendering modes via `.symbolRenderingMode(_:)`: `.monochrome` (single tint, the default and safest choice for toolbar/list icons), `.hierarchical` (one base color at varying opacities to imply depth), `.palette` (two or three colors you assign explicitly with `.foregroundStyle(_:_:)`), and `.multicolor` (the symbol's built-in Apple-defined palette, e.g. for weather or battery icons). Pick the mode intentionally — do not default every icon to `.multicolor` just because it is available; most UI icons read best as `.monochrome` inheriting the surrounding tint.

```swift
Image(systemName: "wifi.exclamationmark")
    .symbolRenderingMode(.palette)
    .foregroundStyle(.white, .orange)
```

## Symbol Variants

Many symbols ship in variants — `.fill`, `.circle`, `.square`, `.slash` — accessible either as separate symbol names (`"heart"` vs `"heart.fill"`) or via `.symbolVariant(_:)` applied to a whole hierarchy so selected/unselected states stay visually consistent (e.g., outline for inactive, filled for selected/active, matching tab bar conventions). Use `.fill` variants for selected or emphasized states and outline variants for neutral/inactive states, mirroring how system tab bars and toggles behave. For symbols that support it, `variableValue` (0...1) can represent a continuous quantity (signal strength, volume) instead of swapping discrete icons.

```swift
Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
```

## App Icon Design for iOS 26 (Liquid Glass)

iOS 26 app icons are built as a small stack of layers (typically background + one or two foreground layers) composed with Apple's Icon Composer tool, which applies the Liquid Glass rendering — specular highlights, translucency, and depth — automatically at render time rather than the designer baking a flat effect into a single PNG. Keep the design to one clear focal subject with generous padding; avoid cramming a wordmark, UI chrome, or a screenshot of the app into the icon.

## App Icon Variants & Grid

Provide the standard light, dark, and tinted variants (the system swaps them based on the user's appearance and Home Screen tint settings), and design so the same layered composition reads correctly in all three — dark and tinted modes desaturate/recolor layers automatically, so avoid baking a color that only makes sense in light mode into the top layer. Design on Apple's rounded-square icon grid and let Icon Composer/Xcode apply the platform mask rather than pre-masking a custom corner radius, so the icon matches the exact iOS 26 corner geometry across device sizes. Never include the system's own rounded-rect mask, drop shadow, or gloss inside your artwork — Liquid Glass adds that.

## Icon Do's and Don'ts

Do keep the composition simple enough to recognize at Home Screen size (roughly 60pt) and at Settings-row size (roughly 29pt) — a detailed illustration that reads well full-screen often becomes mud at icon scale. Don't render text, a screenshot of the app's UI, or a photorealistic scene as the icon; Apple explicitly discourages both. Do reuse the icon's core shape/color language inside the app (e.g., in a launch screen or empty state) so the icon feels like a promise the app keeps, and generate the actual `.icon` bundle/asset catalog entries with Xcode 26's Icon Composer rather than hand-exporting flat PNGs per size.

## Symbol Accessibility

An `Image(systemName:)` used as a standalone tappable control needs an accessibility label, since the symbol name itself ("chevron.right") is not meaningful when read by VoiceOver. Wrap icon-only buttons with a `Label` (which supplies both the symbol and a text description) or set `.accessibilityLabel(_:)` explicitly rather than shipping an unlabeled glyph.

```swift
Button {
    dismiss()
} label: {
    Image(systemName: "xmark")
}
.accessibilityLabel("Close")
```

## Forward Note: iOS 27

iOS/iPadOS 27 was announced at WWDC26 and is in beta as of this writing; treat iOS/iPadOS 26 as the stable typography, symbol, and icon baseline for shipping apps, and re-check SF Symbols/Icon Composer release notes before adopting anything iOS 27–specific ahead of general availability.
