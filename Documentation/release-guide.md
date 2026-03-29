# Dragon Release Guide

This guide is for publishing Dragon `1.0` to GitHub and packaging the shipping DMG.

## Release Metadata

- app version: `1.0`
- build number: `1`
- bundle identifier: `yp.Dragon`

## Pre-Release Checklist

- build the `Dragon` scheme successfully in `Release`
- verify notch mode
- verify menu bar mode
- verify staged file import and drag-out
- verify `Compress`
- verify `Convert`
- verify `Share`
- verify `AirDrop`
- verify `Tag`
- verify `Cloud Sync`
- verify the app icon in Finder and Dock
- verify the DMG window background, icon placement, and hidden helper folders

## GitHub Release Files

Recommended release payload:

- `Dragon-1.0.dmg`
- source code zip from GitHub
- source code tar.gz from GitHub

Recommended repository docs at release time:

- `README.md`
- `CHANGELOG.md`
- `Documentation/current-product-state.md`

## Suggested Git Tag

```bash
git tag -a v1.0 -m "Dragon 1.0"
git push origin main --tags
```

## Suggested GitHub Release Notes

Title:

```text
Dragon 1.0
```

Body:

```text
Dragon 1.0 is the first official public release.

Highlights:
- notch and menu bar entry modes
- staged file actions from a floating top-center panel
- compression, conversion, share, AirDrop, Finder tag, and cloud sync flows
- Finder-style staged file tiles with drag-out support
- Quick Look thumbnails for previewable staged files
- configurable appearance and action visibility
```

## DMG Packaging Flow

1. Build the app in `Release`.
2. Copy `Dragon.app` into a temporary DMG staging folder.
3. Add an `Applications` symlink.
4. Add the custom `.background/background.png`.
5. Create a read-write DMG.
6. Mount it and arrange:
   - `Dragon.app` on the left
   - `Applications` on the right
7. Hide `.background` and remove or hide `.fseventsd`.
8. Eject the mounted image.
9. Convert the DMG to compressed `UDZO`.

## Suggested Final Artifact Name

```text
Dragon-1.0.dmg
```

## Post-Release

- confirm the uploaded DMG opens cleanly on a second machine or user account
- confirm drag-to-Applications flow works
- confirm Gatekeeper and signing behavior are acceptable for your distribution method
