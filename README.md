# Dragon

Dragon is a free, open-source macOS utility that stages files in a floating notch or menu bar panel and runs quick file actions without leaving your current workspace.

Version: `1.0`  
Build: `1`

## What Dragon Does

Dragon lets you stage files once, then run compact actions from a persistent top-center panel.

Current actions:

- `Compress`
- `Convert`
- `Share`
- `AirDrop`
- `Tag`
- `Cloud Sync`

## Highlights

- two entry modes:
  - `Notch`
  - `Menu Bar`
- smooth open and close animation for notch mode
- compact floating panel designed around the notch region
- drag files in to stage them
- click the staged area to import files
- drag staged files back out into Finder or other apps
- Finder-style staged tiles with Quick Look thumbnails when available
- staged filenames shown without file extensions
- per-user action visibility controls
- inline settings for appearance, enabled actions, and entry mode
- selectable menu bar icon style
- native save panels, folder pickers, share sheet, and AirDrop flow

## Conversion Coverage

Dragon currently supports same-category conversion for many common formats.

Shipped coverage includes:

- images:
  - `PNG`
  - `JPEG`
  - `HEIC`
  - `TIFF`
  - `BMP`
  - `GIF`
  - `WebP`
- audio:
  - `WAV`
  - `AIFF`
  - `AIFC`
  - `CAF`
  - `M4A`
  - `AAC`
  - `FLAC`
  - `MP3`
  - `OGG`
  - `AC3`
  - `3GPP`
  - `3GPP-2`
- video:
  - `MP4`
  - `M4V`
  - `MOV`
  - `AVI`
  - `MKV`
  - `MPEG`
- documents:
  - `PDF`
  - `TXT`
  - `RTF`
  - `HTML`
  - `DOC`
  - `DOCX`
  - `ODT`
  - `WordML`
  - `WebArchive`
  - `Markdown`

## Tech Notes

- SwiftUI UI surface with an AppKit-hosted floating `NSPanel`
- reviewed bundled `ffmpeg` path for expanded media conversion
- in-repo LibreOffice bundle kept as a future office conversion path
- accessory utility app, not a traditional dock-first app workflow

## Project Structure

- [Dragon/DragonApp.swift](/Users/yoavperetz/Developer/Dragon/Dragon/DragonApp.swift)
  - panel hosting
  - notch/menu bar presentation
  - outside-click handling
  - save/picker sheet hosting
- [Dragon/ContentView.swift](/Users/yoavperetz/Developer/Dragon/Dragon/ContentView.swift)
  - main UI
  - staged files
  - actions
  - settings
  - conversion and workflow wiring
- [Documentation/current-product-state.md](/Users/yoavperetz/Developer/Dragon/Documentation/current-product-state.md)
  - detailed handoff and current implementation notes
- [CHANGELOG.md](/Users/yoavperetz/Developer/Dragon/CHANGELOG.md)
  - release history
- [Documentation/release-guide.md](/Users/yoavperetz/Developer/Dragon/Documentation/release-guide.md)
  - GitHub and DMG release flow

## Build

1. Open `Dragon.xcodeproj` in Xcode.
2. Select the `Dragon` scheme.
3. Build a `Release` archive or `Release` product.
4. Package the built app into a DMG using the release guide.

## License

Dragon is licensed under Apache 2.0. See `LICENSE`.
