# Dragon Current Product State

This document is the canonical handoff note for the current Dragon `1.0` build.

It captures what is implemented, what changed during the recent UI/interaction pass, and what is intentionally still rough or deferred.

## Product Summary

Dragon is a macOS notch utility that stages files and runs compact file actions from a floating top-center panel.

The app currently exposes these action slots:

- `Compress`
- `Convert`
- `Share`
- `AirDrop`
- `Tag`
- `Cloud Sync`

The menu is personalized through inline settings and is designed to stay visually anchored under the notch region while expanding downward.

## Verified Current Behavior

### Panel and interaction model

- Dragon launches as an accessory app and uses a floating borderless `NSPanel`.
- Dragon supports two entry modes:
  - `Notch`
  - `Menu Bar`
- In `Notch` mode, the panel stays anchored to the same top-center notch position in collapsed and expanded states.
- In `Menu Bar` mode, the panel opens from the menu bar icon and keeps a fixed top offset under the bar.
- The host window now stays at a fixed maximum size to avoid resize jank.
- Open and close use a fade-first transition instead of animated panel resizing.
- The expanded shell is pinned to the top of the fixed host so opening settings does not push the menu upward.
- The settings close animation is intentionally smooth because the host does not resize during the close path.
- The first expanded open now restores the full interactive region immediately instead of waiting for a later mode or layout refresh.
- File pickers and save panels are presented through AppKit host windows above the notch panel instead of behind it.
- Outside clicks collapse the panel while clicks inside the visible menu content stay interactive.

### Main menu layout

- The top bar contains only the title and settings button.
- The top-left Dragon logo is shown in the expanded menu.
- Action buttons are shown in a compact 5-column grid.
- The menu action grid is driven by persisted action visibility settings.
- The staged-files section sits below the action grid.

### Staged files area

- The `Choose Files` button was removed from the top bar.
- Clicking empty space in the staged-files card opens the file picker.
- Drag-and-drop staging still works.
- Staged items are now horizontally scrollable Finder-style tiles instead of full-width rows.
- Staged items use the real file icon as a fallback and Quick Look thumbnails when available.
- Staged items can be dragged back out of Dragon into Finder or other apps.
- Staged filenames are shown without their file extensions.
- Each staged tile has a small red circular remove badge at its top-right corner.
- The empty staged area and the filled staged area now use the same fixed viewport height.

### Settings drawer

- The settings drawer is integrated into the main menu shell rather than appearing as a detached second card.
- The old `Done` button was removed from the settings header.
- Opening settings keeps the menu visually anchored instead of pushing the shell upward.
- The drawer currently has three tabs:
  - `Appearance`
  - `Actions`
  - `Settings`
- `Appearance` contains the existing controls for:
  - background red
  - background green
  - background blue
  - background opacity
  - font style
- `Actions` lets the user show or hide actions from the menu.
- `Settings` is currently a placeholder tab for future work.

### Appearance customization

- Background color is stored with `@AppStorage`.
- Background opacity is stored with `@AppStorage`.
- Font style is stored with `@AppStorage`.
- Enabled action selection is stored with `@AppStorage`.
- Entry mode selection is stored with `@AppStorage`.
- Menu bar icon style selection is stored with `@AppStorage`.
- When opacity is effectively `100%`, Dragon disables the material underlay and renders the exact selected RGB color directly.
- This specifically fixed the previous inability to render true black and true white.
- When the shell is effectively white, internal semantic text colors switch to a light color scheme so labels render dark and stay readable.

### Menu bar mode

- Menu bar mode is fully wired through the same Dragon panel surface rather than a second UI implementation.
- The app installs a native `NSStatusItem` when menu bar mode is selected.
- The menu bar icon supports two persisted styles:
  - full-color Dragon logo
  - white Dragon logo
- Clicking the status item toggles the Dragon panel open and closed.
- Switching entry modes collapses and reopens the panel cleanly instead of leaving the old presentation state behind.

### Compression

- `Compress` is implemented.
- Compression uses a real archive save flow.
- The app asks for archive name and destination before writing.
- Archive creation runs through the current compression service layer and returns a real output file.

### Conversion

- `Convert` is implemented for one staged file at a time.
- The save panel now updates its filename and type live when the selected output format changes.
- Dragon no longer rewrites the output path after the save panel closes.
- This fixed the previous sandbox permission failures for formats like `GIF`, `BMP`, and `TIFF`.

Verified image conversion path:

- `PNG` -> `JPEG`
- `PNG` -> `HEIC`
- `PNG` -> `GIF`
- `PNG` -> `BMP`
- `PNG` -> `TIFF`

Implementation note:

- Common bitmap exports now use a more reliable `NSBitmapImageRep` path.
- `HEIC` still uses Image I/O with explicit destination capability checks.

### Sharing

- `Share` uses the native macOS share sheet.
- `AirDrop` uses the native macOS AirDrop sharing service.
- Both actions are disabled when no files are staged.

### Finder Tag

- `Finder Tag` no longer silently applies a fixed tag named `Dragon`.
- It now opens a tag-selection flow before applying anything.
- The current implementation allows the user to choose:
  - tag name
  - tag color
- The selected Finder tag is then applied to all staged files.

Important note:

- The current Finder Tag picker works, but the UX is still not considered polished.
- It is functional but should be treated as a known rough edge that likely needs another design pass.

### Cloud Sync

- `Cloud Sync` is implemented as a folder-targeted copy flow.
- The user chooses a synced destination folder through a native directory picker.
- The flow defaults to local iCloud Drive when available, but works with any synced folder.

### App icon

- Dragon now uses the Icon Composer-based app icon asset.
- The Xcode project build setting was corrected so Finder and Dock use the intended app icon asset name.

## Important UI Decisions That Were Made

These decisions were deliberate and should not be casually reverted in future turns:

- Do not animate the panel frame between collapsed and expanded states.
- Keep the notch host at a fixed maximum size.
- Animate visible content with fade-based transitions instead of window resizing.
- Keep the expanded menu pinned to the top of the host canvas.
- Keep `Notch` and `Menu Bar` as two entry modes over the same panel implementation.
- Present file and save panels through AppKit host windows above the notch panel.
- Keep settings visually integrated into the menu shell rather than detached.
- Keep staged items compact and horizontally scrollable.
- Keep the top bar minimal and avoid restoring a dedicated `Choose Files` button.

## Current Known Gaps

- The Finder Tag picker needs a better UI pass.
- The `Settings` tab is a placeholder and intentionally does not expose real controls yet.
- Action ordering is fixed; users can show or hide actions but cannot reorder them yet.
- The action grid is compact, but no drag-to-reorder behavior exists yet.
- The notch positioning is still top-center oriented and not true hardware-notch aware.
- LibreOffice is bundled in the repository as a future engine path, but it is not part of the current verified surfaced conversion behavior.

## Files Most Relevant To The Current Product Surface

- `Dragon/DragonApp.swift`
  - floating panel host
  - AppKit bridge callbacks
  - panel anchoring, entry-mode switching, outside-click handling, and sheet presentation
- `Dragon/ContentView.swift`
  - main notch UI
  - staged files UI
  - action grid
  - settings tabs
  - menu bar entry-mode preferences
  - conversion/compression/share/tag/cloud-sync service wiring
- `Dragon.xcodeproj/project.pbxproj`
  - app icon asset build setting

## Safe Next Steps

Good next product conversations can continue from this state with:

- polishing the Finder Tag picker UI
- improving the `Actions` tab visual design
- allowing drag-to-reorder for enabled actions
- adding real controls under the `Settings` tab
- expanding conversion coverage further
- making the notch trigger truly hardware-notch aware
