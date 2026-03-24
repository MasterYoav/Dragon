# Conversion Engines

This directory is reserved for optional bundled third-party conversion engines.

Dragon should not ship binaries in this directory unless the compliance requirements in the repository have been completed.

Relevant documents:

- [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)
- [`Documentation/licensing-and-commercialization.md`](../Documentation/licensing-and-commercialization.md)
- [`Documentation/ffmpeg-bundling-plan.md`](../Documentation/ffmpeg-bundling-plan.md)
- [`Documentation/libreoffice-bundling-plan.md`](../Documentation/libreoffice-bundling-plan.md)
- [`Documentation/release-compliance-checklist.md`](../Documentation/release-compliance-checklist.md)

## Intended Layout

Examples:

- `ConversionEngines/ffmpeg`
- `ConversionEngines/ffprobe`
- `ConversionEngines/LibreOffice.app`
- `ConversionEngines/manifests/ffmpeg.lgpl.example.json`
- `ConversionEngines/manifests/libreoffice.mpl.example.json`

## Rules

1. Do not add third-party binaries here without recording their version and source.
2. Do not add FFmpeg here unless it is an intentionally reviewed `LGPL` build.
3. Do not add LibreOffice here without including the required notices and version metadata.
4. Do not change engine builds silently between releases.
