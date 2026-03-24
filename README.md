# Dragon

Dragon is a macOS notch utility inspired by Dropzone 5 and NotchNook, designed to stay open-source and free.

This first prototype establishes the core interaction model:

- an invisible notch-sized hover target at the top center of the screen
- a floating notch panel that expands downward from that target
- drag-and-drop staging for one or multiple files
- compact action slots for `Compress`, `Convert`, `Quick Share`, `AirDrop`, `Finder Tag`, and `Cloud Sync`
- inline appearance settings for menu background color, opacity, and font style

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

## Current Status

What works now:

- hover-based notch reveal
- invisible collapsed toggle sized to the notch footprint
- downward-expanding main menu
- file staging through drop or `Choose Files`
- inline settings that extend from the bottom of the main menu
- live updates for background color, opacity, and font style

What is still placeholder:

- the action buttons do not execute real workflows yet
- the notch trigger is positioned top-center, not true hardware-notch aware
- the app still needs real implementations for compression, conversion, sharing, and provider integrations

## Documentation

Implementation notes for this first version live in [`Documentation/phase-01-prototype.md`](Documentation/phase-01-prototype.md).
