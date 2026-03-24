# Dragon Phase 01: Notch Popup Prototype

## Goal

This phase establishes the first product interaction for Dragon:

- stage one or more files
- reveal a compact notch-inspired popup
- present a modern, Liquid Glass-styled action surface

This is intentionally an early product shell, but it now launches as a floating notch-style utility panel instead of a standard desktop window. The current build proves the interaction model before we add:

- global notch and top-edge detection
- clipboard observation
- actual compression and conversion pipelines
- service integrations

## What Was Built

### 1. A notch-style popup shell

`ContentView` now renders a compact capsule that is hosted inside a dedicated floating panel. When the user:

- drags file URLs onto the capsule, or
- chooses files manually through `NSOpenPanel`

the capsule expands into a larger action panel.

### 1.1 A utility-style launch model

`DragonApp` no longer launches a normal `WindowGroup`.

Instead it now:

- uses an `NSApplicationDelegateAdaptor`
- switches the app to `.accessory` activation policy
- creates a borderless `NSPanel`
- positions that panel at the top center of the active display

This makes Dragon behave more like a notch utility than a conventional document or desktop app.

### 1.2 A collapsed notch state

Dragon now has two panel states:

- collapsed: the notch handle stays hidden until the pointer enters the notch zone, then reveals a compact icon-only capsule
- expanded: the full action surface opens directly beneath the notch, without a separate top pill

The notch capsule itself is now the control for opening and collapsing the panel. The AppKit host resizes and repositions the floating panel whenever this state changes so the expanded interface stays anchored under the notch instead of appearing as a freestanding desktop window.

The expanded menu now also closes when the user clicks anywhere outside the panel, and its container uses a lighter frosted material treatment instead of a dense opaque background.

The expanded layout is now intentionally more compact:

- the top explanatory copy is removed
- action tiles show icon plus title only
- the header exposes settings instead of a manual collapse button
- the collapsed hover handle is now a custom animated notch scene instead of a static circular toggle

The settings window now includes live appearance controls for:

- menu background color
- menu background opacity
- menu font style

### 2. Multi-file staging

Dropped or imported files are converted into `QueuedDropItem` values. Each staged item stores:

- source `URL`
- byte count
- directory status
- a context-aware symbol for quick scanning

The UI deduplicates incoming URLs to avoid duplicate staging rows.

### 3. Liquid Glass presentation

The prototype uses SwiftUI Liquid Glass APIs as the visual foundation:

- `GlassEffectContainer`
- `glassEffect(_:in:)`
- glass button styles

This follows Apple’s current guidance to lean on system materials instead of layering custom blur stacks.

### 4. Action surface scaffolding

The expanded panel includes placeholder action groups for the workflows Dragon is expected to support later:

- compress
- convert
- quick share
- AirDrop
- Finder tagging
- cloud sync placeholder

These are UI scaffolds only in this phase. No backend workflow is attached yet.

## Architecture Notes

- `DragonApp` now delegates launch to AppKit so the app can own a top-level floating panel directly.
- `ContentView` owns the current prototype state. This is still acceptable for phase 01 because the logic is local to a single interaction surface.
- The next phase should extract staging and action execution into dedicated types before service integrations begin.

## Design Notes

- The top capsule is the main interaction anchor and mirrors the mental model of dropping into the MacBook notch or the top-center edge on notchless Macs.
- The content view itself is now self-sized and transparent so the surrounding window chrome does not read like a desktop app.
- The interactive elements use Liquid Glass sparingly to stay aligned with Apple’s Tahoe-era guidance.

## Known Gaps

- The app is positioned like a notch utility and now collapses into a compact notch capsule, but it still does not monitor the real notch area or top edge globally.
- Clipboard-based file staging is not implemented yet.
- The action buttons do not execute workflows yet.
- File metadata is intentionally lightweight for now.
- The requested screenshot-based feature matrix could not be mapped in this phase because the screenshot itself was not part of the workspace/context.

## Recommended Next Step

Build the real floating overlay or panel layer that can appear at the top center of the current display, then connect the current staged-file UI to that window instead of the main content area.
