# LibreOffice Bundling Plan

This document defines the cautious path for adding LibreOffice to Dragon as a bundled office conversion engine.

## Goals

- broaden office and presentation conversion beyond the current built-in macOS stack
- support `pptx` export into additional office formats through a self-contained bundled engine
- preserve a clean open-source and commercial-compliance posture

## Official Sources Only

Use only official LibreOffice distribution sources.

- Download page: <https://www.libreoffice.org/download/download/>
- License page: <https://www.libreoffice.org/about-us/licenses/>

Do not fetch LibreOffice app bundles from mirrors or repackaging services unless they are explicitly documented by the LibreOffice project.

## Compliance Rules

Before LibreOffice is committed into `ConversionEngines/` or shipped inside `Dragon.app`:

1. Record the exact LibreOffice version.
2. Record the exact official download URL.
3. Record the exact bundle path and executable path for `soffice`.
4. Store the required license texts and notices under `ConversionEngines/licenses/`.
5. Create a completed manifest in `ConversionEngines/manifests/`.
6. Run the repository review script against the unpacked bundle.
7. Complete the release checklist in `Documentation/release-compliance-checklist.md`.

## Intended Layout

The intended bundled layout is:

- `ConversionEngines/LibreOffice.app`
- `ConversionEngines/manifests/libreoffice.mpl.example.json`
- `ConversionEngines/licenses/`
- `Scripts/fetch_libreoffice_official.sh`
- `Scripts/review_libreoffice_bundle.sh`

Dragon resolves the executable at:

- `ConversionEngines/LibreOffice.app/Contents/MacOS/soffice`

and supports a local development override at:

- `.build/libreoffice/LibreOffice.app/Contents/MacOS/soffice`

## Acquisition Workflow

1. Download the official macOS disk image.
2. Mount the disk image read-only.
3. Copy `LibreOffice.app` into `.build/libreoffice/`.
4. Review the copied bundle with `Scripts/review_libreoffice_bundle.sh`.
5. Create the final manifest.
6. Only then consider copying the reviewed bundle into `ConversionEngines/`.

## Product Scope

LibreOffice should be used only for document and presentation conversion where the built-in Apple stack is insufficient.

Current intended Dragon usage:

- `pptx` -> `docx`
- `pptx` -> `odt`
- future office-family conversions that require a real office engine

Keep images, PDFs, and media on the lighter native or FFmpeg-backed paths when possible.
