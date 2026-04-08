# Dragon Website Session Handoff

Last updated: 2026-04-08

This file documents the current state of the Dragon marketing site so the next session can continue from the exact same point without re-discovering the implementation.

## Project Summary

- Project path: `/Users/yoavperetz/Developer/DragonWP`
- Stack: Astro 5
- Main goal: a classy, restrained marketing site for Dragon, visually inspired by Alcove, but themed black/red/orange and adapted to Dragon’s actual UI.
- Primary focus of recent work: the interactive hero demo that showcases Dragon inside a MacBook frame and supports both notch mode and menu bar mode.

## Core Files

- `src/pages/index.astro`
  - Main landing page.
  - Contains all page copy, navbar, hero, live demo markup, and inline interaction script.
- `src/styles/global.css`
  - All visual styling, layout, responsive rules, and hero demo positioning.
- `src/layouts/BaseLayout.astro`
  - Shared document shell and global stylesheet import.
- `public/`
  - Holds the real Dragon UI captures and the MacBook frame asset used by the hero demo.

## Package State

Current `package.json`:

```json
{
  "name": "dragon-website",
  "type": "module",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "dev": "astro dev",
    "start": "astro dev",
    "build": "astro build",
    "preview": "astro preview"
  },
  "devDependencies": {
    "astro": "^5.13.0"
  }
}
```

## Current Site Structure

As of this handoff, `src/pages/index.astro` is organized like this:

1. Hero section
   - Left side: headline, short body copy, metadata.
   - Right side: MacBook-based interactive Dragon demo with subtle in-wallpaper hint text that changes by mode while closed.
2. Workflow section
3. Actions section
4. Formats section
5. Final centered download band with an App-Store-style button, a plain GitHub icon, and oversized faded `Dragon` wordmark

Navbar state:

- Uses the real Dragon app icon in the brand.
- The center section-link nav has been removed.
- Has a GitHub icon button.
- Has a Download button.
- The GitHub icon button appears before the Download button.
- The header is now visually integrated into the page rather than rendered as a pill-shaped glass bar.
- On scroll, the header gains a subtle frosted-glass backdrop so underlying content fades beneath it.

Relevant `index.astro` line anchors at the time of writing:

- Navbar: around lines 61-90
- Hero copy: around lines 93-114
- Interactive demo markup: around lines 116-167
- Final download band: around lines 220-277
- Demo script: around lines 283-389

## Hero Copy Constraint

The user reported that this paragraph was getting visually crowded by the live preview:

> Dragon gives you a compact file station under the notch or in the menu bar, so you can collect files once and run fast actions without leaving the task you are already in.

To compensate, the copy column was narrowed in CSS:

- `.hero-copy { max-width: 32rem; }`
- `.hero-body { max-width: 27rem; }`

If the hero is rebalanced later, check that this paragraph is still not visually cut by the oversized live preview.

## Public Assets in Use

These are the important files currently used by the site:

- `public/macbook.png`
  - Blank MacBook frame template.
  - The built-in physical notch from this PNG must remain the visible notch.
- `public/demo-menubar.png`
  - Menubar image for notch mode.
  - This version does not show the Dragon icon.
- `public/demo-menubarmode.png`
  - Menubar image for menu bar mode.
  - This version includes the Dragon icon and is used as the real visual trigger region.
- `public/demo-hovering.png`
  - Hover-expanded notch visual for closed notch mode.
- `public/demo-main.png`
  - Dragon open with no staged files.
- `public/demo-staged.png`
  - Dragon open with staged content.
- `public/dragon-icon.png`
  - Real app icon used in the navbar brand.
- `public/dragon-logo.png`
  - Secondary Dragon mark asset.

Current file sizes from `public/`:

- `macbook.png`: 4.3 MB
- `demo-menubar.png`: 80 KB
- `demo-menubarmode.png`: 88 KB
- `demo-hovering.png`: 12 KB
- `demo-main.png`: 57 KB
- `demo-staged.png`: 70 KB
- `dragon-icon.png`: 1.7 MB
- `dragon-logo.png`: 147 KB

## Source of Screenshot Assets

These assets came from the user’s Desktop screenshots folder:

- `/Users/yoavperetz/Desktop/Screenshots/macbook.png`
- `/Users/yoavperetz/Desktop/Screenshots/hovering.png`
- `/Users/yoavperetz/Desktop/Screenshots/main.png`
- `/Users/yoavperetz/Desktop/Screenshots/staged.png`
- `/Users/yoavperetz/Desktop/Screenshots/menubar.png`
- `/Users/yoavperetz/Desktop/Screenshots/menubarmode.png`

The website currently depends on those processed copies already placed in `public/`. If the screenshots are updated in the future, they need to be recopied into `public/`.

## Live Demo Architecture

The interactive demo is not a browser recreation of the whole Dragon UI. It is a controlled interactive composition made from:

- one MacBook frame PNG
- one clipped screen region inside that frame
- one menubar image for notch mode
- one menubar image for menu bar mode
- one hover-state notch image
- one app-open image for empty state
- one app-open image for staged state
- invisible click and hover hit areas
- CSS transforms and opacity transitions

This means the experience is image-led, but still interactive.

### Demo Root

The hero demo root is:

```html
<div
  class="interactive-demo"
  data-demo
  data-mode="notch"
  data-state="staged"
  data-open="false"
  data-hover="false"
>
```

These attributes are the source of truth:

- `data-mode`: `notch` or `menu`
- `data-state`: `empty` or `staged`
- `data-open`: `true` or `false`
- `data-hover`: `true` or `false`

### Main Elements

Inside the demo:

- `.macbook-demo`
  - whole camera target that now scales when the app opens
- `.macbook-frame`
  - the MacBook shell image
- `.macbook-notch-trigger`
  - invisible hotspot over the physical notch area
- `.macbook-screen`
  - the clipped visible display area inside the laptop frame
- `.screen-menubar.screen-menubar-notch`
  - notch-mode menubar image
- `.screen-menubar.screen-menubar-menu`
  - menu-bar-mode menubar image
- `.screen-menubar-trigger`
  - invisible hotspot over the Dragon menubar icon inside `demo-menubarmode.png`
- `.screen-hover-image`
  - the collapsed hover-state notch image
- `.screen-panel-stack`
  - container for the open Dragon screenshots
- `.screen-panel.screen-panel-empty`
  - open Dragon empty state
- `.screen-panel.screen-panel-staged`
  - open Dragon staged state
- `.demo-toolbar`
  - mode and state controls shown below the live demo

## Current Interaction Behavior

### Notch Mode

- Menubar image shown: `demo-menubar.png`
- Dragon icon in the menubar is not shown, because notch mode should not enter via the menu bar icon.
- The built-in MacBook notch from `macbook.png` is the visible notch.
- Hovering the invisible notch hotspot should show `demo-hovering.png`.
- Clicking the notch hotspot opens Dragon.
- When open, the Dragon panel sits at the top of the display region so it appears behind the built-in notch rather than below it.

### Menu Bar Mode

- Menubar image shown: `demo-menubarmode.png`
- No custom visible button should appear.
- The invisible hotspot is aligned over the real Dragon icon baked into `demo-menubarmode.png`.
- Clicking that hotspot opens Dragon beneath the icon.

### Shared Behavior

- The `Empty` and `Staged` buttons swap between `demo-main.png` and `demo-staged.png`.
- Clicking outside the open panel closes it.
- Open and close are animated.
- The whole live-preview camera scales when the menu opens, rather than scaling only the menu image.

## Current Geometry and Positioning

These values were tuned against `macbook.png` and are important if the demo is adjusted later.

### MacBook Screen Geometry

From previous measurement work:

- `macbook.png` dimensions: `3944 x 2564`
- visible screen region approximately:
  - top: `y = 301`
  - bottom: `y = 2263`
  - left: `x = 462`
  - right: `x = 3482`
- notch opening at top approximately:
  - left ear ends: `x = 1787`
  - right ear begins: `x = 2157`

### CSS Mapping

Current `.macbook-screen` mapping in `src/styles/global.css`:

```css
.macbook-screen {
  top: 11.62%;
  left: 11.56%;
  width: 76.88%;
  height: 76.7%;
  clip-path: polygon(
    0 0,
    43.87% 0,
    43.87% 3.26%,
    56.13% 3.26%,
    56.13% 0,
    100% 0,
    100% 100%,
    0 100%
  );
}
```

Important meaning:

- the screen is clipped to leave the physical notch visible
- the menubar and the Dragon panel live underneath the MacBook template
- the frame image is layered above the interactive content

### Trigger Positions

Current important positioning values in `src/styles/global.css`:

- `.macbook-notch-trigger`
  - `top: 11.62%`
  - `left: 50%`
  - `width: 10.5%`
  - `height: 3.15%`
- `.screen-menubar-trigger`
  - `top: 0.25%`
  - `left: 82.85%`
  - `width: 3.55%`

### Panel Positions

Current panel placement:

- Notch mode:
  - `.screen-panel` starts at `top: 0`
  - horizontally centered
  - width is `25.96%`
- Menu bar mode:
  - panel top is `3.55%`
  - panel left is `82.85%`
  - panel opens under the real icon region

## Camera Zoom

The user clarified that the desired effect is not menu-image zoom, but full camera zoom around the active area.

Current implementation:

- `.macbook-demo` is the camera target
- base state:

```css
.macbook-demo {
  transform: scale(1);
  transform-origin: 50% 14%;
}
```

- menu mode changes camera origin:

```css
.interactive-demo[data-mode="menu"] .macbook-demo {
  transform-origin: 82.85% 15%;
}
```

- open state camera zoom:

```css
.interactive-demo[data-open="true"] .macbook-demo {
  transform: scale(1.7);
}
```

This `1.7` scale is the latest stronger zoom setting. If the user later says the camera still needs stronger magnification, this is the first value to adjust.

## Script Behavior

The inline script in `src/pages/index.astro` manages the live preview state.

Key functions:

- `syncDemoButtons()`
  - syncs active state on mode and state buttons
- `setMode(mode)`
  - updates `data-mode`
  - resets hover
- `setState(state)`
  - updates `data-state`
- `setOpen(open)`
  - updates `data-open`
  - updates `aria-expanded` on both triggers

Key event flows:

- notch trigger mouseenter and focus:
  - show hover image only in notch mode and only while closed
- notch trigger mouseleave and blur:
  - clear hover state
- notch trigger click:
  - toggle open only in notch mode
- menu trigger click:
  - toggle open only in menu mode
- document click:
  - when panel is open, clicking outside the panel and outside all control triggers closes the menu

The outside-click behavior is intentional and user-requested.

## Visual Decisions the User Explicitly Asked For

Do not casually undo these.

- Use the real Dragon app icon in the navbar, not a fake placeholder icon.
- GitHub in the navbar should be an icon button, not a text button.
- GitHub button should appear before the Download button.
- The site should stay simple and classy, not overloaded.
- Remove the hero eyebrow, the hero download CTA, the intro paragraph band, and the bottom closing CTA area.
- The workflow, actions, and formats areas should read as compact centered feature objects rather than large editorial blocks.
- The bottom of the page should end with a cleaner Alcove-style centered CTA band rather than a split closing section.
- The final CTA row should use a dark App-Store-style download button plus a plain GitHub icon without a bordered chip.
- The live preview should sit inside a MacBook template.
- The built-in notch from the MacBook template should be the visible notch.
- The menubar should sit under the MacBook template, not above it.
- The notch-mode menubar and menu-bar-mode menubar are separate images.
- In menu bar mode, use the real Dragon icon from the menubar screenshot, not a custom visible button.
- In notch mode, hovering should show the enlarged collapsed notch visual.
- In notch mode, clicking should open Dragon from the notch and place it behind the physical notch.
- In both modes, clicking outside the open app should close it.
- The whole live preview should zoom in when the panel opens so the UI reads more clearly.

## Current CSS Anchors

Useful spots in `src/styles/global.css` as of this handoff:

- hero copy width adjustments and hero metadata grid: around lines 203 and 263
- live demo wrapper: around line 306
- MacBook camera element: around line 315
- notch trigger: around line 335
- clipped screen: around line 352
- menubar images: around line 381
- menu icon trigger hotspot: around line 402
- hover image: around line 423
- panel image rules: around line 440
- notch mode state rules: around lines 459-492
- menu mode state rules: around lines 494-528
- camera zoom origin and open-state scale: around lines 530-536
- compact feature-grid section styling: around lines 607-679
- final centered CTA band and ghost wordmark: around lines 681-759

## Current Markup Anchors

Useful spots in `src/pages/index.astro` as of this handoff:

- navbar: around lines 61-90
- hero copy: around lines 94-114
- interactive hero demo: around lines 116-167
- final download band: around lines 227-268
- demo script: around lines 274-380

## Validation State

The site has been built successfully multiple times during this work.

Known successful verification command:

```bash
npm run build
```

At the time of this handoff, no unresolved build failure is known.

## Known Open Risks

There is no major blocker known right now, but these are the areas most likely to need future tuning:

- tiny alignment shifts if the screenshot assets are replaced with new exports
- camera zoom strength if the user wants even stronger focus
- invisible hotspot alignment if the menu bar screenshots change
- responsive behavior if the hero composition is pushed further on very small screens

## Recommended Starting Point for the Next Session

1. Read this file.
2. Open `src/pages/index.astro` and `src/styles/global.css`.
3. Run `npm run build`.
4. If the user asks for visual tuning, start with:
   - `.macbook-screen`
   - `.macbook-notch-trigger`
   - `.screen-menubar-trigger`
   - `.screen-panel`
   - `.macbook-demo`
5. If the user replaces screenshots, update the files in `public/` first before adjusting CSS.

## Current “Ready to Resume” Status

The project is at a near-publish state.

The last accepted direction from the user was:

- the overall hero is now correct
- the notch positioning is correct
- the camera zoom concept is correct
- the remaining work, if any, is likely refinement rather than structural rework

The most recent concrete visual change before this handoff was doubling the live-preview camera zoom amount so the open app appears larger and easier to read.
