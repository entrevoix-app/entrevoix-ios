---
name: ios-app-architecture
description: >-
  Use when structuring an iOS/iPadOS 26 SwiftUI app's App/Scene/WindowGroup
  setup, adapting layout across size classes with NavigationSplitView vs
  NavigationStack, choosing @State/@Binding/@Observable/@Bindable/@Environment
  for state and dependency injection, deciding MV vs MVVM, wrapping UIKit
  views with UIViewRepresentable/UIViewControllerRepresentable, or reacting
  to scenePhase and app lifecycle events.
---

Structure the app-level scaffolding — App/Scene, adaptive layout, state flow, and UIKit interop — for an iOS/iPadOS 26 SwiftUI app.

## Use this skill when

- Writing or reviewing the `App` protocol conformer, `@main`, and `WindowGroup`/`Scene` setup, including multiple `WindowGroup`s for iPad multi-window.
- Deciding whether a screen needs `NavigationSplitView` (collapsing to `NavigationStack` on compact width) versus a plain `NavigationStack`.
- Choosing between `@State`, `@Binding`, `@Observable`/`@Bindable`, `@Environment`, or legacy `@StateObject`/`@ObservedObject`/`@EnvironmentObject`.
- Deciding MV (view + `@Observable` model) vs MVVM, or untangling a view that owns too much logic.
- Wrapping a UIKit view/controller with `UIViewRepresentable`/`UIViewControllerRepresentable`, or embedding SwiftUI in UIKit via `UIHostingController`.
- Handling app/scene lifecycle: `@UIApplicationDelegateAdaptor`, `@Environment(\.scenePhase)`, or reasoning about a widget's place in the app's architecture.

## Do not use this skill when

- Choosing colors/typography/materials — use ios-hig-foundations.
- Choosing which specific navigation/control component to render — use ios-hig-components-structure or ios-hig-components-controls.
- Deciding how a form field or picker should look/behave — use ios-inputs.
- Testing, privacy, or App Store distribution — use ios-best-practices.
- Fixing Swift-language-level concurrency/Sendable errors unrelated to SwiftUI state — that's a separate swift-concurrency skill outside this repo.
- Picking spacing, padding, or layout metrics for a single view's contents — that's a visual-design decision, not an architectural one.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested architecture works.

1. Identify the architectural question and open EXACTLY ONE reference file from the list below.
2. Design the phone-width (compact) layout first, then verify it adapts correctly at regular width (iPad) and in a resized/split iPad window — don't design iPad-first.
3. For state, default to `@Observable` + `@Bindable`/`@Environment` for new code; only use `@StateObject`/`@ObservedObject`/`@EnvironmentObject` when touching pre-existing `ObservableObject` code for consistency.
4. Keep views thin: push business logic and formatting into the model/view-model, not the `View` body.
5. Drop to UIKit (`UIViewRepresentable`/`UIViewControllerRepresentable`/`UIHostingController`) only when SwiftUI genuinely has no equivalent API; wrap the smallest UIKit surface possible.
6. Wire lifecycle concerns (`scenePhase`, `UIApplicationDelegateAdaptor`) at the `App`/`Scene` level, not buried inside leaf views.
7. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not introduce a second competing state-management pattern in the same feature.
- Do not rewrite an entire working `ObservableObject` hierarchy to `@Observable` as a side quest — only do it if that's the actual task.
- Stop as soon as data flows correctly end-to-end on both size classes.

## Reference files

- `references/app-scene-adaptive-layout.md` — open when working on `App`/`Scene`/`WindowGroup`, multi-window iPad support, or size-class-adaptive layout (`NavigationSplitView` vs `NavigationStack`).
- `references/state-management-data-flow.md` — open when choosing or fixing state ownership/propagation, `@Observable` vs `ObservableObject`, dependency injection via `@Environment`, or MV vs MVVM structure.
- `references/uikit-interop-lifecycle.md` — open when wrapping UIKit views/controllers, embedding SwiftUI in UIKit, or handling app/scene lifecycle and `scenePhase`.
