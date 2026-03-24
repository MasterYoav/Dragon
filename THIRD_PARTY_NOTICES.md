# Third-Party Notices

Dragon currently relies on Apple-provided system frameworks and command-line tools that ship with macOS. Dragon may later bundle optional third-party conversion engines to broaden conversion support.

This file defines the compliance baseline for that future work.

## Current Built-In Dependencies

Dragon currently uses the following Apple-provided components that are expected to be present on supported macOS systems:

- `ditto`
- `textutil`
- `afconvert`
- `unzip`
- AVFoundation
- PDFKit
- Image I/O
- UniformTypeIdentifiers

These are platform components, not third-party redistributed binaries inside Dragon.

## Planned Optional Bundled Engines

Dragon is designed to support optional bundled conversion engines under `ConversionEngines/`.

The current intended engines are:

- `FFmpeg`
- `LibreOffice`

No third-party engine should be committed to this repository or distributed in release builds until the compliance checklist below is satisfied.

## FFmpeg

Official project:

- <https://ffmpeg.org/>

Official legal page:

- <https://ffmpeg.org/legal.html>

Dragon policy:

- Prefer an `LGPL` build of FFmpeg.
- Do not ship an FFmpeg build configured with `--enable-gpl` unless Dragon's licensing strategy is intentionally updated for GPL compatibility.
- Do not ship an FFmpeg build configured with `--enable-nonfree`.
- Preserve the exact build configuration used for distributed binaries.
- Include the FFmpeg license text and attribution in the app bundle and repository.
- Keep a reproducible record of the exact FFmpeg source version and build script used to produce shipped binaries.

## LibreOffice

Official project:

- <https://www.libreoffice.org/>

Official license page:

- <https://www.libreoffice.org/about-us/licenses/>

Dragon policy:

- Treat LibreOffice as a separately bundled conversion engine.
- Preserve all required notices and license texts in the app bundle and repository.
- Record the exact LibreOffice version shipped with each release.
- Avoid modifying bundled LibreOffice binaries unless there is a strong reason and the compliance impact is reviewed first.

## Required Compliance Checklist Before Shipping Bundled Engines

Every release that includes bundled third-party engines must satisfy all of the following:

1. Record the exact engine version and source location.
2. Record the exact build configuration used for the shipped binary.
3. Include third-party license texts in the repository and app bundle.
4. Include attribution and notices in release artifacts.
5. Confirm the app's own license remains compatible with the bundled engine license terms.
6. Confirm trademark usage is accurate and does not imply endorsement.
7. Confirm no prohibited codecs or nonfree build flags were introduced unintentionally.

## Commercial Use

Bundling open-source engines does not automatically prevent Dragon from charging money for pro features or commercial distribution.

What matters is compliance with the license terms of the bundled engines.

Dragon policy:

- Commercial features are allowed.
- Compliance work is mandatory.
- Before a public paid release that bundles third-party engines, Dragon should undergo a legal/compliance review.
