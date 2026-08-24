---
name: ios-hig-foundations
description: >-
  Use when making iOS/iPadOS visual and interaction design decisions covered
  by Apple's HIG Foundations group: layout, safe areas, Dynamic Island/notch
  avoidance, margins, alignment, size classes and iPad adaptivity, system and
  semantic colors, accent color and tinting, Dark Mode, Liquid Glass
  materials and .glassEffect, typography, Dynamic Type and text styles, SF
  Symbols weight/scale/rendering modes and variants, app icon design
  (Liquid Glass layered icons), motion and Reduce Motion, sound and haptic
  feedback, and iOS UI writing/microcopy for iOS/iPadOS 26 apps.
---

Helps an agent apply Apple's Human Interface Guidelines "Foundations" group to iOS/iPadOS 26 apps so layout, color, materials, typography, icons, motion, sound/haptics, and copy read as native, current-generation Apple UI rather than a generic or dated port.

## Use this skill when

- Placing content inside safe areas, avoiding the Dynamic Island/notch/home indicator, or choosing margins, alignment, and spacing
- Adapting layout for iPad size classes (regular/compact width and height)
- Choosing colors: system/semantic colors, accent color, tint, or Dark Mode support
- Deciding whether and how to apply Liquid Glass materials (`.glassEffect`, `GlassEffectContainer`, `.ultraThinMaterial`) vs a plain background
- Choosing fonts, text styles, or ensuring Dynamic Type support
- Picking SF Symbols, symbol weight/scale, rendering mode, or symbol variants
- Designing or reviewing an app icon, including the Liquid Glass layered composition and light/dark/tinted/clear variants
- Adding an animation or transition and deciding whether it should respect Reduce Motion
- Adding a sound effect or haptic feedback for an interaction
- Writing iOS UI copy/microcopy: capitalization, terminology, button labels
- Doing a quick privacy-by-design check on what a screen visibly exposes

## Do not use this skill when

- Choosing which navigation/tab bar/control structure to use — use ios-hig-components-structure or ios-hig-components-controls.
- Deciding app architecture (`@State`, App/Scene structure, adaptive layout code) — use ios-app-architecture.
- Choosing input methods (gestures, keyboard, Apple Pencil, drag and drop) — use ios-hig-inputs.
- Designing broader interaction patterns (onboarding, search, undo, settings) — use ios-hig-patterns.
- General coding, testing, or performance practices unrelated to visual design — use ios-best-practices.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested design decision is made.

1. Identify the design question and open EXACTLY ONE reference file from the list below.
2. Prefer semantic/system colors and materials over hardcoded hex or literal RGB values — this keeps Dark Mode, Liquid Glass, and accessibility settings (increased contrast, reduced transparency) working automatically.
3. Respect safe areas and Dynamic Type by default; do not disable or override either without a documented reason.
4. Apply Liquid Glass materials only to elements that float above content (bars, controls, sheets), never as a base layer for ordinary content, and never nest glass inside glass.
5. Keep animation purposeful (reflects a real state or spatial change) and gate nonessential motion behind `accessibilityReduceMotion`.
6. Use haptics and sounds only to confirm meaningful actions, following system feedback conventions, never as decoration.
7. Match iOS writing conventions (sentence-case UI text, concise action-oriented labels) for any copy produced.
8. Stop here once the design decision is applied in code — do not also implement unrelated structure or behavior.

Anti-loop rules:
- ONE reference file per task.
- Do not hardcode colors, fonts, or icon assets when a system-provided semantic equivalent exists.
- Stop as soon as the visual/design decision is applied.

## Reference files

- `references/layout-color-materials.md` — open for safe areas, size classes, margins/alignment, system/semantic colors, Dark Mode, and Liquid Glass material usage.
- `references/typography-icons-sf-symbols.md` — open for system font/text styles, Dynamic Type, SF Symbols configuration, and app icon (Liquid Glass) design.
- `references/motion-sound-haptics-writing.md` — open for animation/Reduce Motion, sound effects, haptic feedback, UI writing/microcopy, and a privacy-by-design note.
