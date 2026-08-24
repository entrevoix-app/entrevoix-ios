---
name: ios-hig-components-controls
description: >-
  Use when adding or reviewing buttons, toggles, pickers, segmented controls,
  sliders, steppers, List/Table swipe actions, pull-to-refresh, text fields,
  text views, labels, progress indicators, or context menus in an
  iOS/iPadOS 26 SwiftUI app — anything the user taps, drags, types into, or
  long-presses to invoke an action.
---

Help build and review iOS/iPadOS 26 content controls — buttons, lists,
pickers, text input, and context menus — so they match Apple's Human
Interface Guidelines and Liquid Glass conventions.

## Use this skill when

- Choosing a `Button` role and style (`.borderedProminent`, `.bordered`, `.plain`, glass emphasis).
- Adding `.swipeActions`, `.refreshable`, or sections to a `List`.
- Wiring up a `Picker` (wheel, menu, segmented) or `DatePicker`.
- Adding a `Slider`, `Stepper`, `Toggle`, or `Label`.
- Building `TextField`, `SecureField`, or `TextEditor` input with the right keyboard type or autocapitalization.
- Showing progress with `ProgressView` (determinate or indeterminate).
- Adding a `.contextMenu` or long-press preview to a row or card.

## Do not use this skill when

- Structuring navigation, tab bars, sheets, or sidebars — use ios-hig-components-structure.
- Deciding the underlying behavioral pattern (validation UX, modality, onboarding) — use ios-hig-patterns.
- Choosing color, typography, materials, or spacing tokens in the abstract — use ios-hig-foundations.
- Wiring text input to app state, forms, or persistence logic — use ios-app-architecture.
- Picking gesture/keyboard/pointer input mechanics unrelated to a specific control — use ios-inputs.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested control works.

1. Identify which control is needed and open EXACTLY ONE reference file from the list below.
2. Keep every tappable target at least 44x44pt, even if the visible glyph is smaller.
3. Default to the iOS-idiomatic control style: switch-style `Toggle` (not a checkbox), native `Picker`/`DatePicker` styles, system `Button` roles — do not hand-roll a replacement.
4. Bind the control directly to typed, minimal state (`@State`, `@Binding`, or a model property) — no stringly-typed or duplicated state.
5. Match the code snippet's structure from the reference file; adjust only labels, bindings, and data.
6. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not duplicate an existing control; edit the existing one in place.
- Stop as soon as the control renders, meets the minimum tap-target size, and its binding works.

## Reference files

- `references/buttons-toggles-pickers.md` — open when adding or styling a `Button`, `Toggle`, `Picker` (wheel/menu/segmented), `DatePicker`, `Slider`, `Stepper`, or `Label`.
- `references/lists-tables-swipe-actions.md` — open when building a `List`, sectioned data, `.swipeActions`, or `.refreshable`.
- `references/text-fields-progress-context-menus.md` — open when adding `TextField`/`SecureField`/`TextEditor` input, a `ProgressView`, or a `.contextMenu`.
