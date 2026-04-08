# Dragon Website

Marketing website for Dragon, built with Astro.

## Location

This site lives inside the main Dragon repository at `DragonWP/`.

## Stack

- Astro 5
- Static output

## Local Development

From the repository root:

```bash
cd DragonWP
npm install
npm run dev
```

Build locally:

```bash
cd DragonWP
npm run build
```

Preview the production build:

```bash
cd DragonWP
npm run preview
```

## Deploying To Vercel

This site is deployed from the main `MasterYoav/Dragon` repository as a separate Vercel project.

Required Vercel settings:

- Root Directory: `DragonWP`
- Framework Preset: `Astro`
- Build Command: `npm run build`
- Output Directory: `dist`

After the Vercel project is connected correctly, every push to the production branch redeploys the site.

CLI alternative:

```bash
vercel --cwd DragonWP
vercel --cwd DragonWP --prod
```

## Important Files

- `src/pages/index.astro`
  - Main landing page markup and demo script
- `src/styles/global.css`
  - All visual styling and interactive demo behavior
- `public/`
  - MacBook frame, UI screenshots, and brand assets
- `docs/session-handoff.md`
  - Detailed implementation notes and visual decisions

## Interactive Demo Notes

The hero showcase is image-led, not a recreated app UI. It uses:

- a MacBook frame
- clipped screen artwork
- notch mode and menu bar mode screenshots
- open-state screenshots
- invisible hotspots
- CSS transforms and small state-driven interactions

If the screenshots are replaced, update the files in `public/` before retuning layout values.
