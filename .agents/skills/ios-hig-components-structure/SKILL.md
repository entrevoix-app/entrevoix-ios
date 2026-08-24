---
name: ios-hig-components-structure
description: >-
  Use when building or reviewing the structural/navigation shell of an
  iOS/iPadOS SwiftUI app — navigation bars and large titles (NavigationStack,
  .navigationTitle, .navigationBarTitleDisplayMode), tab bars (TabView, the
  iOS 26 floating/Liquid Glass tab bar, tabBarMinimizeBehavior, badges),
  toolbars (.toolbar, ToolbarItem placements), sidebars and split views on
  iPad (NavigationSplitView 2/3-column, collapsing to a stack on iPhone),
  sheets (.sheet, .presentationDetents), popovers (.popover on iPad/Mac
  Catalyst), action sheets and alerts (.confirmationDialog, .alert), and page
  controls (TabView with .page style) for iOS/iPadOS 26 apps.
---

Helps you assemble the structural shell — navigation bars, tab bars, toolbars, sidebars/split views, sheets, popovers, alerts, and page controls — of an iOS/iPadOS 26 SwiftUI app so it matches Apple's HIG.

## Use this skill when

- Setting up or fixing a `NavigationStack`, its title (`.navigationTitle`), or large-title display mode.
- Building or adjusting a `TabView`, including the iOS 26 floating Liquid Glass tab bar, minimize-on-scroll behavior, or badges.
- Adding, reordering, or fixing a `.toolbar { }` and its `ToolbarItem` placements.
- Building or fixing an iPad sidebar or 2-/3-column `NavigationSplitView`, including how it collapses to a stack on iPhone.
- Adding a `.sheet`, sizing it with `.presentationDetents`, or choosing a `.popover` for iPad/Mac Catalyst.
- Adding a `.confirmationDialog` or `.alert`, or a paged `TabView` with page-style dots.

## Do not use this skill when

- Choosing specific input controls (buttons, pickers, lists content) — use ios-hig-components-controls.
- Deciding modal behavior patterns like sheet-vs-alert-vs-full-screen at the UX level — use ios-hig-patterns (this skill covers how to build the chosen structure).
- Structuring App/Scene declarations, adaptive layout code, or multi-window iPad support — use ios-app-architecture.
- Choosing colors, typography, spacing, or SF Symbols weight/rendering — use ios-hig-foundations.
- Working with text fields, steppers, sliders, or other fine-grained input widgets — use ios-hig-inputs.
- General app-level conventions not tied to one structural component — use ios-best-practices.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested UI structure works.

1. Identify which structural component is needed and open EXACTLY ONE reference file from the list below.
2. Use `NavigationSplitView` for iPad sidebar apps so it adapts to a stack on iPhone automatically; don't hand-roll a split layout with `HStack`.
3. Keep tab bars to 5 or fewer top-level destinations; put anything beyond that behind a "More" pattern only as a last resort, not the default.
4. Match toolbar actions and placements consistently across size classes — don't add an action on iPad that silently disappears on iPhone.
5. Prefer `.presentationDetents` on a `.sheet` for content that only needs partial height; reserve full-height sheets for focused multi-step tasks.
6. Use `.popover` on iPad/Mac Catalyst contexts and let it adapt to a sheet on iPhone automatically — don't force a popover's fixed anchor behavior on a compact width.
7. Verify the structure builds and behaves correctly in both compact (iPhone) and regular (iPad) size classes before stopping.
8. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not duplicate an existing navigation/tab/sheet structure; edit the existing declaration.
- Stop as soon as the structure renders and behaves correctly on both iPhone and iPad.

## Reference files

- `references/navigation-tab-bars-toolbars.md` — open when working on `NavigationStack` titles, `TabView`/the iOS 26 floating tab bar, badges, or `.toolbar`/`ToolbarItem` placements.
- `references/sidebars-split-views-ipad.md` — open when building an iPad sidebar, `NavigationSplitView`, or handling its collapse to a stack on iPhone.
- `references/sheets-popovers-alerts.md` — open when adding a `.sheet`, `.presentationDetents`, `.popover`, `.confirmationDialog`, `.alert`, or a paged `TabView`.
