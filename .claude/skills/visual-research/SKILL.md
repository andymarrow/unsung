---
name: visual-research
description: Browse the web like a designer for UI inspiration. Search Pinterest, Dribbble, Behance, Mobbin, Awwwards or Google Images, open pins and shots, screenshot pages and download the images so they can be looked at, then turn what was seen into concrete design decisions. Use whenever the user asks to research, find inspiration, "look at Pinterest/Dribbble", match a reference link, or make a UI look like the best apps out there. Also use when the user pastes a Pinterest, Dribbble or Behance link.
---

# Visual research

A headless Chromium (Playwright) that searches inspiration sites and saves
what it sees as images you can open with the Read tool. Use the images; never
describe a reference you did not actually look at.

## Before you start

1. Check the network can reach the site:
   `curl -s -o /dev/null -m 10 -w "%{http_code}" https://www.pinterest.com/`
   `000` means the environment's network policy blocks it. Tell the user, in
   one line, to allow it (cloud environment settings → Network access →
   Full, or add the domains below) and stop. Do not guess what a blocked
   page shows.
   Domains to allow: `www.pinterest.com i.pinimg.com dribbble.com
   cdn.dribbble.com www.behance.net mir-s3-cdn-cf.behance.net mobbin.com
   www.awwwards.com www.google.com`
2. Playwright: the script finds the pre-installed copy (`/opt/node-tools`).
   Elsewhere: `npm i -g playwright && npx playwright install chromium`.

## Commands

All write into `--out DIR` (default `./research/<timestamp>`; use your
scratchpad) as `page-*.png` screenshots, `img-*.jpg` images and `index.json`
(src, alt text, page URL).

```bash
S=.claude/skills/visual-research/scripts/browse.mjs
node $S search pinterest "music app ui dark minimal" --max 24 --out $OUT
node $S search dribbble "karaoke app" --max 16 --out $OUT
node $S images "https://www.pinterest.com/pin/<id>/" --max 6 --out $OUT
node $S shot   "https://some-site.com" --scrolls 3 --mobile --out $OUT
```

Sites for `search`: pinterest, dribbble, behance, mobbin, google-images,
awwwards. Mobbin and some Pinterest boards need a signed-in session: on a
desktop, `node $S login https://www.pinterest.com/` saves `state.json`; run
later commands with `BROWSE_STATE=path/to/state.json`.

## How to research (do this, in order)

1. **Search 2–3 queries per site** that describe the product, not the
   aesthetic you already have in mind (e.g. "music player app", "karaoke
   lyrics screen", "audio waveform ui", "music app onboarding").
2. **Look at every image** you downloaded with Read. Discard generic or
   low-quality shots. Keep 4–8 strong references.
3. For each kept reference, note **what specifically** makes it good:
   background and surface colours, where the accent appears and where it
   does not, type scale and weights, spacing rhythm, corner radii, how
   images are framed, what moves and how.
4. **Extract principles, never copy.** Do not reproduce layouts, logos,
   illustrations or artwork. Credit the source URLs in the design brief.
5. Turn the principles into token changes (colour, type, spacing, radius,
   motion) and component changes, then render goldens/screenshots and
   compare side by side with the references before calling it done.

## Report to the user

A short list: each reference (link) → the one or two principles taken from
it → where it shows up in the app. Then before/after screenshots.
