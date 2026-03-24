# Dragon Phase 01 Prototype

## Goal

Build the first usable Dragon prototype around the macOS notch interaction:

- collapse into the notch area
- reveal on hover
- expand downward into a compact workflow menu
- accept dropped files and stage them for later actions
- expose live appearance controls for rapid iteration

## What Was Built

### App shell

- The app no longer launches as a normal document-style desktop window.
- `DragonApp.swift` uses an `NSApplicationDelegateAdaptor` and a custom `NSPanel`.
- The panel is:
  - borderless
  - floating at status-bar level
  - transparent
  - available across spaces
  - anchored to a notch-centered activation zone

### Collapsed state

- The collapsed state is now visually invisible.
- The interactive target matches the notch footprint instead of showing a separate visible pill or icon.
- Hovering the activation zone reveals the utility surface, and clicking the zone expands the menu.

### Expanded menu

- The expanded menu opens downward from the notch instead of appearing as a standard centered app window.
- The menu is compact and uses a frosted-glass style background with configurable tint and opacity.
- The top row contains:
  - the `Dragon` title
  - a settings control
  - a `Choose Files` button

### Action layout

- The current action surface contains six placeholder workflow slots:
  - `Compress`
  - `Convert`
  - `Quick Share`
  - `AirDrop`
  - `Finder Tag`
  - `Cloud Sync`
- Each action is reduced to icon plus title to keep the panel compact.

### File staging

- Dropped or imported files are converted into `QueuedDropItem` models.
- The panel tracks:
  - file URL
  - byte count
  - whether the item is a directory
  - a contextual SF Symbol
- The staged-files area shows either:
  - an empty state
  - or a list of staged items with remove controls

### Inline settings

- Settings no longer need to live in a separate utility window.
- The settings section expands from the bottom of the main menu and collapses back into the regular menu.
- Current live controls:
  - background red channel
  - background green channel
  - background blue channel
  - background opacity from `0%` to `100%`
  - font design choice

## Design Decisions

### Why `NSPanel`

SwiftUI alone is not enough for this interaction because the app needs utility-window behavior:

- top-edge positioning
- hover reveal
- cross-space persistence
- non-standard window chrome

`NSPanel` is the correct host for this prototype phase.

### Why a fixed host width

The panel host width is kept constant between collapsed and expanded states so the expanded menu does not appear to drift right or left when opening.

### Why inline settings

The earlier separate settings window created lifecycle and crash risk around auxiliary panels and picker interactions. Inline settings are simpler, safer, and better aligned with the product’s utility-panel UX.

## Known Limitations

- The notch target is aligned to the screen center, not the physical hardware notch geometry.
- The action buttons are placeholders and do not yet run real jobs.
- The app does not yet detect clipboard-based file intake.
- There is not yet any provider or automation backend for actions like conversion, compression, or cloud sync.

## Next Recommended Steps

1. Implement real action backends starting with compression.
2. Add a real conversion pipeline with file-type-aware options.
3. Introduce service integrations, excluding Amazon S3 as requested.
4. Make the activation area notch-aware per display where possible.
5. Add tests around staging, layout state, and settings persistence.
