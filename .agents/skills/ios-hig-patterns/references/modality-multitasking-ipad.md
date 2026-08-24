# Modality, Full Screen, and iPad Multitasking

## The modality decision tree

Ask, in order: does this block the current task and demand an immediate yes/no or short input? Use an `alert`. Does it need a full self-contained flow the person can dismiss or complete independently (create item, edit settings, sign in)? Use a `sheet`. Does it need to fully replace context because returning to the previous screen mid-flow makes no sense (camera capture, onboarding, a paywall)? Use a `fullScreenCover`. Does it need a small, contextual bit of information or a short set of options anchored to the control that triggered it, on a device with room to show it as non-blocking? Use a `popover` — on iPhone, SwiftUI automatically falls back to a sheet, so don't hand-roll that fallback.

```swift
.sheet(isPresented: $showEditor) { EditorView() }
.fullScreenCover(isPresented: $showOnboarding) { OnboardingView() }
.popover(isPresented: $showInfo, arrowEdge: .top) { InfoView() }
.alert("Turn On Location?", isPresented: $showPrompt) { … }
```

## Sheets

A sheet keeps the parent context alive underneath and should be used for any task that is a detour from, not a replacement of, the current screen. On iPadOS 26, a sheet presented from a resizable app window opens sized appropriately to that window, not to the full screen, so don't assume sheet content has full-screen width available — lay it out to work at moderate widths. Use `.presentationDetents` for a partial-height sheet when the content is short (a quick-look, a share action) so the parent stays visible.

```swift
.sheet(isPresented: $showQuickLook) { QuickLookView() }
    .presentationDetents([.medium, .large])
```

## Full-screen cover

Reserve `fullScreenCover` for flows where any lingering view of the previous screen would be confusing or where the task is the entire point of that moment — camera/scanner UI, a forced sign-in wall, first-run onboarding. Always give it an explicit, obvious dismiss action; a full-screen cover with no visible way out is a dead end for a person and for an agent testing the flow.

## Popovers on iPad

A popover is the iPad-idiomatic way to show contextual detail or a short menu without losing place in the underlying content — attach it to the exact control that triggered it via an anchor, not to the middle of the screen. Do not use a popover for anything requiring more than a glance of reading or more than a few actions; past that size, it should be a sheet.

## Alerts and confirmation dialogs

Alerts interrupt everything and should be reserved for decisions that are destructive, irreversible, or block further progress until answered; anything else belongs in inline feedback or a banner (see data-entry-feedback-loading.md). When there are more than two clear choices, use `confirmationDialog` (action sheet) instead of stacking buttons in an alert.

```swift
.confirmationDialog("Export As", isPresented: $showExport) {
    Button("PDF") { export(.pdf) }
    Button("Image") { export(.image) }
    Button("Cancel", role: .cancel) { }
}
```

## Going full screen

Full-screen presentation (media viewers, immersive games, camera) should hide chrome the person doesn't need and provide one obvious way back — a close button or a recognized swipe/tap gesture — never rely on a hidden gesture as the only exit. Save and restore whatever state existed before entering full screen so returning doesn't lose position or selection.

## iPhone size-class adaptivity

On iPhone, and on iPad when Stage Manager/windowing is off, drive layout from `UserInterfaceSizeClass` / `horizontalSizeClass`: stack in `.compact`, use two-column or larger layouts in `.regular`. This size-class model still matters on iPad — it's what determines your layout inside whatever window size Stage Manager or Split View gives you — but it's no longer the whole multitasking story on iPad.

```swift
@Environment(\.horizontalSizeClass) private var sizeClass
var body: some View {
    if sizeClass == .compact { CompactLayout() } else { RegularLayout() }
}
```

## iPadOS 26 windowing: what changed

iPadOS 26 replaced the old Split View/Slide Over model as the primary multitasking story with a macOS-style windowing system available on every iPadOS 26–compatible device (previously Stage Manager was limited to M-series/select A-series iPads): apps run in freely resizable windows with traffic-light controls (minimize, close, enter fullscreen), a system menu bar appears via a swipe down from the top, and windows can be tiled by dragging to screen edges. Design for a window that can be resized to almost any width and aspect ratio at any time, not just the handful of fixed multitasking widths from the old model — that means testing narrow, square, and wide window shapes, not just "iPhone-narrow" and "iPad-full."

## Adopting the menu bar and window sizing

Expose meaningful actions through SwiftUI's `.commands` scene modifier (or UIKit's `buildMenu(with:)`) so they surface correctly in the iPadOS 26 menu bar — actions that only live in a toolbar or hidden gesture are invisible there. Where a window has a genuine minimum usable size (e.g., a two-pane layout that can't compress further), set `UIWindowScene.sizeRestrictions` rather than letting content clip or overlap when a person drags a window smaller.

```swift
.commands {
    CommandGroup(replacing: .newItem) {
        Button("New Document") { createDocument() }
            .keyboardShortcut("n", modifiers: .command)
    }
}
```

## Classic Stage Manager and Split View/Slide Over

Devices and contexts still exist where the app runs under classic Split View (side-by-side) or Slide Over (floating overlay); the safe default is the same adaptive, size-class-driven layout used for iPhone, because it degrades correctly whether the visible width is a third of the screen or the whole thing. Never assume your app is the only visible window, and never assume it's frontmost — resume gracefully when the person switches back after using another app alongside yours.

## Dismissal and interruption rules

Every modal surface needs a predictable dismissal path: sheets support swipe-to-dismiss by default (disable it with `.interactiveDismissDisabled()` only when losing in-progress data would be destructive, and pair that with an explicit Cancel/Save button so there's still a way out). Never stack a second modal on top of an already-presented sheet or alert — finish or dismiss the first before presenting the next, both to match the HIG and to avoid an agent getting stuck unable to find the top-most control.

```swift
.sheet(isPresented: $showEditor) { EditorView() }
    .interactiveDismissDisabled(hasUnsavedChanges)
```

## Testing modality and windowing changes

After wiring a modality or multitasking change, verify it directly: present and dismiss the surface, resize the simulator/window to at least one narrow and one wide width, and confirm the menu bar (if you added `.commands`) shows the new item. Treat "looks right at the default simulator window size only" as unverified — the point of the iPadOS 26 windowing model is that the default size is not the only size.

## Forward note: iPadOS 27

iPadOS 27 (WWDC26) is currently in beta at the time of writing; treat any behavior specific to it as provisional and keep building against the shipping iPadOS 26 windowing model described above unless a task explicitly targets the beta.
