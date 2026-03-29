# Changelog

## 1.0

First official Dragon release.

### Added

- notch mode and menu bar mode entry points
- animated floating top-center Dragon panel
- drag-and-drop file staging
- click-to-import staged files area
- drag-out support from the staged area
- Finder-style staged file tiles
- Quick Look thumbnails for previewable staged files
- compression workflow with native save destination selection
- conversion workflow across supported image, audio, video, and document formats
- native share sheet support
- native AirDrop support
- Finder tag workflow
- cloud-folder sync workflow
- inline settings for appearance, actions, and entry mode
- selectable menu bar icon styles
- bundled reviewed `ffmpeg` support for expanded media conversion

### Changed

- refined notch open and close animation behavior
- tightened expanded panel spacing and reduced wasted vertical space
- improved notch hover shape to better match a MacBook-style notch silhouette
- upgraded staged area from text chips to thumbnail tiles
- removed file extensions from staged item labels

### Known Limitations

- notch placement is still top-center anchored, not hardware-notch aware
- Finder Tag UX still needs a later polish pass
- the `Settings` tab remains reserved for future controls
- LibreOffice is present in-repo as a future engine path, not a currently documented user-facing conversion path
