# Dragon Licensing And Commercialization

## Purpose

This document defines the safe path for Dragon to remain open-source while preserving the option to charge money for premium features later.

It is intentionally conservative.

## Core Position

Dragon can remain open-source and still offer paid features or paid distribution.

That is legally and commercially normal.

The main risk is not charging money. The main risk is shipping third-party engines without satisfying their license requirements.

## Safe Strategy

Dragon should follow this model:

1. Keep Dragon's own codebase open-source.
2. Treat third-party conversion engines as separate bundled components.
3. Use the least restrictive viable engine builds.
4. Keep full records of source versions, build flags, notices, and license texts.
5. Run a legal/compliance review before any public paid release that includes bundled engines.

## FFmpeg Policy

Dragon should only ship FFmpeg under a compliance-first policy.

Recommended rule:

- ship only an `LGPL` build unless there is a deliberate licensing decision to move to a GPL-compatible app strategy

Do not ship:

- `--enable-gpl`
- `--enable-nonfree`

Required release metadata for FFmpeg:

- source version
- source URL or commit reference
- build script
- configure flags
- bundled license text
- attribution notice

Official reference:

- <https://ffmpeg.org/legal.html>

## LibreOffice Policy

Dragon may bundle LibreOffice as an office conversion engine if needed for broader document and presentation coverage.

Required release metadata for LibreOffice:

- distributed version
- official source location
- license texts
- attribution notice

Official reference:

- <https://www.libreoffice.org/about-us/licenses/>

## What Dragon Can Safely Monetize

Examples of commercial layers that are compatible with an open-source core:

- pro automation workflows
- additional integrations
- cloud sync services
- team features
- premium presets
- support subscriptions

The presence of open-source engines does not by itself block commercial use.

## What Must Happen Before Paid Releases

Before Dragon ships a paid release with bundled engines:

1. Confirm every bundled engine version and build configuration.
2. Confirm license texts are packaged inside the app and repository.
3. Confirm attribution is present in release artifacts.
4. Confirm Dragon's app license is still compatible with the engines actually shipped.
5. Confirm no disallowed FFmpeg flags or patent-sensitive nonfree configurations were introduced.
6. Run a legal/compliance review.

## Non-Goals

This document is not legal advice.

Its purpose is to reduce avoidable mistakes and force explicit review before Dragon crosses from prototype to public commercial distribution.
