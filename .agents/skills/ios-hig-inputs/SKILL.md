---
name: ios-hig-inputs
description: >-
  Use when implementing or reviewing touch gestures (.onTapGesture,
  .onLongPressGesture, .gesture, swipe/pinch conventions), the on-screen
  keyboard (.keyboardType, .submitLabel, .scrollDismissesKeyboard), Apple
  Pencil support on iPad (PencilKit, hover preview, double-tap/squeeze),
  external keyboard shortcuts (.keyboardShortcut, the iPadOS 26 menu bar),
  pointer/trackpad support on iPad (.hoverEffect, .contextMenu for
  right-click), or Face ID/Touch ID authentication (LocalAuthentication) for
  iOS/iPadOS apps.
---

Guide how an iOS/iPadOS 26 app accepts input — touch gestures, the on-screen keyboard, Apple Pencil, external keyboard/pointer on iPad, and Face ID/Touch ID — so every interaction works well on the device that delivers it without colliding with a system-reserved gesture or shortcut.

## Use this skill when

- Attaching a tap, double-tap, long-press, swipe, drag, or pinch gesture to a view (`.onTapGesture`, `.onLongPressGesture`, `.gesture`).
- Choosing a keyboard type or submit label, or fixing content the on-screen keyboard covers.
- Adding Apple Pencil-specific behavior on iPad: `PencilKit` drawing, hover preview, double-tap/squeeze.
- Assigning an external-keyboard `.keyboardShortcut()`, especially one surfaced in the iPadOS 26 menu bar.
- Adding pointer/trackpad affordances on iPad (`.hoverEffect`, right-click via `.contextMenu`).
- Adding Face ID/Touch ID authentication with `LocalAuthentication`.
- Reviewing whether a custom gesture conflicts with a system-reserved one (edge-swipe-back, Control Center, Notification Center, the Home indicator).

## Do not use this skill when

- Deep accessibility implementation (VoiceOver labels, Dynamic Type auditing) beyond basic input handling — use ios-best-practices.
- Choosing which control to attach a gesture/shortcut to structurally — use ios-hig-components-structure or ios-hig-components-controls.
- Deciding the underlying behavioral pattern (form validation UX, modality, onboarding) — use ios-hig-patterns.
- Wiring input state into app architecture or dependency injection — use ios-app-architecture.
- Mac-only pointer/keyboard conventions unrelated to iPad — that's the macos-hig-inputs skill in the macos-skills repo.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested input behavior works.

1. Identify the input concern and open EXACTLY ONE reference file from the list below.
2. Before adding a custom gesture, check it against the system-reserved gestures in the reference file (edge-swipe-back, top-edge Control Center/Notification Center swipe, bottom-edge Home indicator) and pick a location/direction that doesn't collide.
3. For every Pencil-only, pointer-only, or external-keyboard-only interaction, confirm a plain touch equivalent also exists — this support must be additive, never the only path in.
4. Before assigning `.keyboardShortcut()`, check it against reserved system and menu-bar shortcuts; pick a different combination on conflict.
5. When adding Face ID/Touch ID, always pair it with a passcode or passphrase fallback — never make biometrics the sole way in.
6. Verify the result works with a finger on a touch-only device before treating Pencil, pointer, or keyboard support as done.
7. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not assign a gesture or keyboard shortcut that conflicts with a system-reserved one.
- Do not ship a Pencil-only, pointer-only, or keyboard-only interaction without a touch fallback.
- Stop as soon as the input behavior works across touch, and (where relevant) Pencil/pointer/keyboard.

## Reference files

- `references/touch-gestures-keyboard.md` — open when adding or reviewing tap/long-press/swipe/pinch gestures, resolving a conflict with a system-reserved gesture, or working with the on-screen keyboard (`.keyboardType`, `.submitLabel`, `.scrollDismissesKeyboard`).
- `references/pencil-pointer-biometrics-ipad.md` — open when adding Apple Pencil support (`PencilKit`, hover, double-tap/squeeze), external-keyboard `.keyboardShortcut()` on iPad, pointer/trackpad affordances (`.hoverEffect`, `.contextMenu`), or Face ID/Touch ID authentication.
