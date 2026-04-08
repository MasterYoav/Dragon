# Website Deployment

This document describes how the Dragon marketing website is deployed from the main Dragon repository.

## Source Location

- Repository: `MasterYoav/Dragon`
- Website folder: `DragonWP/`

The website is not deployed from the repository root. It is deployed as a separate Vercel project whose root directory points to `DragonWP`.

## Vercel Project Settings

Use these settings for the website project:

- Root Directory: `DragonWP`
- Framework Preset: `Astro`
- Build Command: `npm run build`
- Output Directory: `dist`

If Vercel does not show `DragonWP` in the folder picker, type `DragonWP` manually in the Root Directory field or set it later in Project Settings.

## First-Time Setup

1. Import the `MasterYoav/Dragon` GitHub repository into Vercel.
2. Create a dedicated Vercel project for the website.
3. Set the Root Directory to `DragonWP`.
4. Confirm the Astro build settings above.
5. Deploy.

## Ongoing Updates

1. Make website changes inside `DragonWP/`.
2. Commit and push to the website branch or `main`.
3. Vercel rebuilds the site from `DragonWP/`.

## Local Commands

Run locally from the repository root:

```bash
cd DragonWP
npm run dev
```

Build locally:

```bash
cd DragonWP
npm run build
```

Deploy with Vercel CLI:

```bash
vercel --cwd DragonWP
vercel --cwd DragonWP --prod
```

## Related Documentation

- `DragonWP/README.md`
- `DragonWP/docs/session-handoff.md`
