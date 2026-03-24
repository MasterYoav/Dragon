# FFmpeg Bundling Plan

## Purpose

This document defines the cautious path for bundling FFmpeg into Dragon without drifting into a risky licensing or release state.

It does not authorize immediate shipping of FFmpeg binaries by itself.

## High-Level Strategy

Dragon should use FFmpeg only as an optional bundled media engine.

Rules:

1. Prefer an `LGPL` FFmpeg build.
2. Do not ship builds configured with `--enable-gpl`.
3. Do not ship builds configured with `--enable-nonfree`.
4. Record the exact source release, checksum/signature verification steps, and configure flags.
5. Review the resulting binary with a repeatable compliance script before any release.

## Source Of Truth

Use official FFmpeg sources and legal guidance:

- Download page: <https://ffmpeg.org/download.html>
- Legal page: <https://ffmpeg.org/legal.html>
- Documentation: <https://ffmpeg.org/documentation.html>

## Recommended First Scope

Do not begin by trying to solve every media format.

First bundled FFmpeg scope for Dragon:

- broaden audio conversion beyond the current Apple-only surface
- broaden video container conversion beyond `MOV`, `MP4`, and `M4V`
- keep image conversion on Apple Image I/O unless there is a concrete need to move it

## Required Release Records

Every shipped FFmpeg bundle must record:

- FFmpeg version
- official source URL
- source checksum or signature verification result
- build host details
- exact `./configure` flags
- final binary `-buildconf` output

## Repository Files

The intended compliance files for FFmpeg are:

- `ConversionEngines/manifests/ffmpeg.lgpl.example.json`
- `ConversionEngines/manifests/ffmpeg.lgpl.local-build.json`
- `ConversionEngines/licenses/`
- `Scripts/build_ffmpeg_lgpl.sh`
- `Scripts/review_ffmpeg_binary.sh`

## Development Integration

Dragon may use a locally reviewed FFmpeg build during development before the binary is formally bundled into release artifacts.

Current development lookup order:

1. bundled binary in `ConversionEngines/`
2. `DRAGON_FFMPEG_PATH` environment override
3. workspace-local reviewed build at `.build/ffmpeg/install/bin/ffmpeg`

This is for development only. A release build should rely on a formally bundled engine plus completed release metadata.

## Pre-Release Review

Before shipping a build that includes FFmpeg:

1. Run the review script against the produced binary.
2. Confirm `--enable-gpl` is absent.
3. Confirm `--enable-nonfree` is absent.
4. Confirm attribution and notices are included in the app.
5. Confirm the release metadata is committed to the repository.

## Non-Goals

This plan is not legal advice.

This plan also does not yet solve patent review or codec distribution review for every jurisdiction. If Dragon moves toward large-scale commercial distribution, that needs a dedicated legal pass.
