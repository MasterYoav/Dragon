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
- `Compress` is now the first live action:
  - it stages selected files into a temporary workspace
  - asks the user where to save the resulting archive
  - creates a `.zip` archive with `ditto`
  - reports success or failure directly in the menu
- `Convert` is now eligibility-gated:
  - if the staged files are not convertible, the button is greyed out and unpressable
  - it only offers output formats from the staged file's own category
  - `pptx` files now expose text-oriented outputs through in-app slide extraction

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
- The staged-files header also includes a `Clear` control when items are present.

### Compression flow

- Compression is now functional for single and multiple files.
- Before compression runs, Dragon presents a save panel so the user can:
  - choose the output folder
  - name the archive
- The implementation uses:
  - a temporary staging directory
  - security-scoped bookmarks for staged file access
  - `NSFileCoordinator` for safer reads
  - `ditto` to generate the final archive
- Action status is shown inline in the menu with:
  - success state
  - failure state
  - a `Reveal` button for successful archives
  - a copy button for sharing the exact status text

### Native sharing

- `AirDrop` is now a live workflow through AppKit `NSSharingService`.
- `Quick Share` now opens the native macOS sharing picker from the notch panel.
- Both actions operate on the currently staged files.
- Both actions now keep the notch panel stable while the share UI is active.
- The notch panel now lowers behind system share UI so AirDrop and the macOS sharing picker stay visible and usable.

### Conversion flow

- `Convert` now supports category-scoped format picking:
  - image files only see image outputs
  - audio files only see audio outputs
  - video files only see video outputs
  - document files only see document outputs
- The current conversion engine stack is:
  - Image I/O for image conversion
  - bundled reviewed `ffmpeg` for expanded audio and video conversion
  - `afconvert` and AVFoundation as Apple-native fallback paths
  - `textutil` for document conversion
  - PDFKit for PDF text extraction
  - in-app `pptx` slide-text extraction for presentation-to-text workflows
- Dragon now resolves external tools through a single engine layer so the app can prefer bundled engines from `ConversionEngines/` without rewriting the conversion UI.
- The repository now also includes explicit compliance documents for future bundled engines so conversion coverage can expand without losing control of licensing risk.
- Verified current FFmpeg-backed media matrix:
  - audio: `WAV` -> `AIFF`, `AIFC`, `CAF`, `M4A`, `AAC`, `FLAC`, `OGG`, `AC3`, `3GPP`, `3GPP-2`
  - video: `MOV` -> `MP4`, `M4V`, `MOV`, `AVI`, `MKV`, `MPEG`
- The earlier `MP3` target was removed from the surfaced conversion UI because the reviewed LGPL-oriented FFmpeg build does not include a working MP3 encoder in this configuration.
- LibreOffice was investigated as a future office engine, but `pptx -> docx` and `pptx -> odt` did not validate reliably through `soffice --headless --convert-to ...` on this setup. Those targets were intentionally removed from the surfaced UI.

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

### Why AppKit-owned save panels

Presenting save panels from inside the notch SwiftUI view proved fragile for this floating utility architecture. The final flow delegates save-panel ownership to the AppKit host so the modal lifecycle stays under the same controller that owns the notch panel.

### Why fade-only menu transitions

Animating the floating `NSPanel` frame produced visibly choppy motion. Dragon now snaps the host window to its final geometry and uses a short opacity-only transition for the visible content, which is materially more stable.

## Known Limitations

- The notch target is aligned to the screen center, not the physical hardware notch geometry.
- `Finder Tag` and `Cloud Sync` remain placeholders.
- The app does not yet detect clipboard-based file intake.
- Broader office and presentation conversion coverage still depends on finding a reliable office-engine path.
- Dragon still does not provide a true full-family any-to-any matrix across all audio, video, and document types. The surfaced targets are intentionally limited to the verified passing set.

## Next Recommended Steps

1. Implement `Finder Tag`.
2. Implement `Cloud Sync`.
3. Expand the verified conversion matrix family by family, source by source, instead of advertising theoretical format support.
4. Introduce service integrations, excluding Amazon S3 as requested.
5. Make the activation area notch-aware per display where possible.

The repository still includes a LibreOffice acquisition and review plan for future investigation:

- `Documentation/libreoffice-bundling-plan.md`
- `Scripts/fetch_libreoffice_official.sh`
- `Scripts/review_libreoffice_bundle.sh`
- `ConversionEngines/manifests/libreoffice.mpl.example.json`
