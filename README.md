# Dragon

Dragon is a macOS notch utility inspired by Dropzone 5 and NotchNook, designed to stay open-source and free.

Dragon is currently licensed under Apache 2.0. See [`LICENSE`](LICENSE).

This first prototype establishes the core interaction model:

- an invisible notch-sized hover target at the top center of the screen
- a floating notch panel that expands downward from that target
- drag-and-drop staging for one or multiple files
- functional `Compress`, `Convert`, `Quick Share`, and `AirDrop` workflows plus compact action slots for `Finder Tag` and `Cloud Sync`
- inline appearance settings for menu background color, opacity, and font style
- a save destination flow for archives and quick staged-file management

## Current Architecture

- `Dragon/Dragon/DragonApp.swift`
  - boots the app as an accessory utility
  - hosts a borderless floating `NSPanel`
  - keeps the collapsed and expanded panel anchored to the same notch centerline
  - handles hover reveal, outside-click collapse, and panel sizing
- `Dragon/Dragon/ContentView.swift`
  - renders the collapsed notch target and expanded menu
  - manages staged files, action layout, and inline settings
  - persists appearance settings with `@AppStorage`
  - owns the conversion catalog and current conversion engines

## Current Status

What works now:

- hover-based notch reveal
- invisible collapsed toggle sized to the notch footprint
- downward-expanding main menu
- file staging through drop or `Choose Files`
- clearing all staged files from the staged-files header
- live archive creation through `Compress`
- save-location and archive-name selection before compression
- category-scoped format conversion through `Convert`
- native `AirDrop` sharing for staged files
- native macOS share-sheet support through `Quick Share`
- bundled reviewed `ffmpeg` for expanded media conversion
- `pptx` text extraction for PDF / TXT / RTF / HTML / Markdown outputs
- post-action status feedback with `Reveal` and copy-status controls
- inline settings that extend from the bottom of the main menu
- live updates for background color, opacity, and font style

What is still placeholder:

- the notch trigger is positioned top-center, not true hardware-notch aware
- sharing and provider integrations still need real backends
- broader office-family conversion still needs a reliable engine path

## Conversion Coverage

Dragon currently converts within a file's own category only.

Verified current media matrix:

- images: Image I/O-backed image-to-image conversion within the exposed image set
- audio: `WAV` -> `AIFF`, `AIFC`, `CAF`, `M4A`, `AAC`, `FLAC`, `OGG`, `AC3`, `3GPP`, `3GPP-2`
- video: `MOV` -> `MP4`, `M4V`, `MOV`, `AVI`, `MKV`, `MPEG`
- documents: built-in `textutil`, PDF extraction, and in-app `pptx` text extraction

The app now resolves conversion tools through a single engine layer. Built-in macOS tools remain the default path for Apple-native formats, and Dragon now prefers bundled reviewed engines from `ConversionEngines/` when present, including the current `ffmpeg` binary for expanded audio/video conversion.

LibreOffice remains documented in the repository as a future office-engine path, but it is not part of Dragon's current verified conversion surface.

## Compliance

Dragon is being prepared to support future bundled conversion engines while remaining open-source and keeping a path open for commercial pro features.

The repository now includes explicit compliance documents:

- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
- [`Documentation/licensing-and-commercialization.md`](Documentation/licensing-and-commercialization.md)
- [`Documentation/ffmpeg-bundling-plan.md`](Documentation/ffmpeg-bundling-plan.md)
- [`Documentation/libreoffice-bundling-plan.md`](Documentation/libreoffice-bundling-plan.md)
- [`ConversionEngines/README.md`](ConversionEngines/README.md)
- [`Documentation/release-compliance-checklist.md`](Documentation/release-compliance-checklist.md)

Bundled engines should only be committed or shipped after they satisfy those requirements. The current bundled `ffmpeg` binary was built and reviewed through the repository's documented LGPL-oriented path.

## Documentation

Implementation notes for this first version live in [`Documentation/phase-01-prototype.md`](Documentation/phase-01-prototype.md).
