# Release Compliance Checklist

Use this checklist before any Dragon release that bundles third-party conversion engines or enables paid distribution with those engines.

## Repository

1. Confirm `LICENSE` and `NOTICE` are present and current.
2. Confirm `THIRD_PARTY_NOTICES.md` reflects every bundled engine.
3. Confirm each bundled engine has a completed manifest based on `ConversionEngines/engine-manifest.template.json`.
4. Confirm each bundled engine's license text is stored under `ConversionEngines/licenses/`.

## Engine Review

1. Confirm the exact engine version.
2. Confirm the exact source URL or source tag/commit.
3. Confirm the exact build flags used.
4. Confirm no prohibited FFmpeg flags were used accidentally.
5. Confirm the engine binary in the app matches the documented manifest.

## FFmpeg-Specific

1. Confirm the shipped build is intentionally `LGPL` if Dragon is not moving to a GPL strategy.
2. Confirm `--enable-gpl` is not present unless explicitly approved.
3. Confirm `--enable-nonfree` is not present.
4. Confirm attribution and license text are included.

## LibreOffice-Specific

1. Confirm the distributed version is recorded.
2. Confirm required notices and license texts are included.
3. Confirm any modifications to the distributed bundle are documented.

## Commercial Release Review

1. Confirm paid features do not remove required open-source notices.
2. Confirm release notes and website copy do not imply endorsement by third-party engine projects.
3. Confirm a legal/compliance review has been completed before the public paid release.
