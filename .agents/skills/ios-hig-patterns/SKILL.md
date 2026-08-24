---
name: ios-hig-patterns
description: >-
  Use when designing or reviewing interaction patterns for iOS/iPadOS 26
  apps: entry forms and inline validation, choosing alert vs inline error vs
  toast/banner vs progress for feedback, going full screen, fast launch and
  state restoration, skeletons/perceived loading, modality decisions (sheet
  vs full-screen cover vs popover-on-iPad vs alert), iPad multitasking
  including Stage Manager and the iPadOS 26 resizable-windows/menu-bar model
  vs classic Split View and size-class adaptivity, local notifications,
  offline/reachability degradation, lightweight onboarding, printing,
  requesting App Store ratings without over-prompting, .searchable search,
  in-app settings vs the system Settings app, UndoManager undo/redo, and
  iPad drag and drop.
---

Guide the behavioral design of iOS/iPadOS 26 app interactions — the HIG Patterns group — so an agent picks the right pattern (not just the right widget) for entering data, giving feedback, presenting modally, running on iPad's windowing model, and the other cross-cutting flows below.

## Use this skill when

- Designing a form: validation timing, keyboard types, autofill hookup.
- Choosing between an alert, inline error text, a toast/banner, or a progress indicator for a given event.
- Deciding whether a flow needs a sheet, a full-screen cover, an iPad popover, or an alert.
- Making a view behave correctly under iPad Stage Manager / resizable windows vs. iPhone size classes.
- Adding local notifications, offline handling, onboarding, printing, App Store review prompts, search, settings, undo/redo, or drag and drop.
- Reviewing an existing iOS/iPadOS screen for a modality, feedback, or multitasking mistake.

## Do not use this skill when

- Choosing visual style (color, typography, materials) — use ios-hig-foundations.
- Picking which specific navigation/control widget to render — use ios-hig-components-structure or ios-hig-components-controls.
- Designing text fields, pickers, or other input widget internals — use ios-inputs.
- Writing the adaptive-layout/window-scene code itself — use ios-app-architecture (come back here for the behavioral pattern).
- Judging general code quality, testing, or project setup — use ios-best-practices.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested behavior works.

1. Identify the interaction pattern needed and open EXACTLY ONE reference file from the list below.
2. Design the phone layout and behavior first, using the correct feedback severity for the situation (alert only for blocking/destructive decisions; inline text for field errors; banner/toast for transient, non-blocking status).
3. Verify the same flow adapts to iPad rather than assuming full-screen: confirm it still works as a resizable window under Stage Manager/iPadOS 26 windowing, and that any popover/sheet choice matches the iPad-specific rule, not just the iPhone default.
4. Wire the minimum supporting API (UNUserNotificationCenter, NWPathMonitor, UndoManager, SKStoreReviewController/requestReview, `.searchable`, UIPrintInteractionController, drag-and-drop modifiers) called for by the pattern — do not add more.
5. Re-check any user-facing prompt (review request, permission request, notification) against the "ask at the right moment, never over-prompt" rule before adding it.
6. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not introduce a new modal surface when an existing sheet/alert already serves the purpose.
- Do not prompt for a review or a permission more than the guidance allows.
- Stop as soon as the interaction pattern behaves correctly on both iPhone and iPad.

## Reference files

- `references/data-entry-feedback-loading.md` — open when building forms/validation, choosing an alert/inline-error/toast/progress feedback style, handling fast launch and state restoration, or designing skeleton/loading states.
- `references/modality-multitasking-ipad.md` — open when deciding sheet vs full-screen cover vs popover vs alert, going full screen, or making a view behave under iPad Stage Manager, resizable windows, the menu bar, tiling, or size-class adaptivity.
- `references/search-settings-undo-notifications.md` — open when adding `.searchable` search, in-app vs system Settings, UndoManager undo/redo, local notifications, offline/reachability handling, onboarding, printing, App Store review prompts, or iPad drag and drop.
