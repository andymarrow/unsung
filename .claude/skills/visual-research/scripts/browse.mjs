#!/usr/bin/env node
// Headless browsing for design research: search inspiration sites, capture
// screenshots and download the images so they can be viewed with Read.
//
//   node browse.mjs search <site> "<query>" [--max 24] [--out DIR]
//   node browse.mjs images <url>            [--max 24] [--out DIR] [--min 300]
//   node browse.mjs shot   <url>            [--scrolls 3] [--mobile] [--out DIR]
//
// Sites: pinterest, dribbble, behance, mobbin, google-images, awwwards.
// Output: PNGs/JPGs plus index.json (src, alt, page) in DIR (default
// ./research/<timestamp>). Set BROWSE_STATE=path/to/state.json to reuse a
// signed-in session saved with `node browse.mjs login <url>` on a desktop.
import { mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
function loadPlaywright() {
  const tries = [
    'playwright',
    '/opt/node-tools/node_modules/playwright',
    `${process.env.HOME}/.npm-global/lib/node_modules/playwright`,
  ];
  for (const t of tries) {
    try { return require(t); } catch {}
  }
  console.error('Playwright not found. Install with: npm i -g playwright');
  process.exit(2);
}
const { chromium, devices } = loadPlaywright();

const SEARCH = {
  pinterest: (q) => `https://www.pinterest.com/search/pins/?q=${encodeURIComponent(q)}`,
  dribbble: (q) => `https://dribbble.com/search/${encodeURIComponent(q).replace(/%20/g, '-')}`,
  behance: (q) => `https://www.behance.net/search/projects?search=${encodeURIComponent(q)}`,
  mobbin: (q) => `https://mobbin.com/search/apps/ios?content_type=screens&q=${encodeURIComponent(q)}`,
  'google-images': (q) => `https://www.google.com/search?tbm=isch&q=${encodeURIComponent(q)}`,
  awwwards: (q) => `https://www.awwwards.com/websites/?text=${encodeURIComponent(q)}`,
};

const argv = process.argv.slice(2);
const cmd = argv[0];
const flag = (name, def) => {
  const i = argv.indexOf(`--${name}`);
  if (i < 0) return def;
  const v = argv[i + 1];
  return v === undefined || v.startsWith('--') ? true : v;
};
const positional = argv.filter((a, i) => i > 0 && !a.startsWith('--') && !argv[i - 1]?.startsWith('--'));
const out = resolve(flag('out', join('research', new Date().toISOString().replace(/[:.]/g, '-'))));
mkdirSync(out, { recursive: true });

function proxy() {
  const p = process.env.HTTPS_PROXY || process.env.https_proxy;
  return p ? { server: p } : undefined;
}

async function open(url, { mobile = false } = {}) {
  const browser = await chromium.launch({
    executablePath: existsSync('/opt/pw-browsers/chromium') ? undefined : undefined,
    proxy: proxy(),
    args: ['--disable-blink-features=AutomationControlled'],
  });
  const state = process.env.BROWSE_STATE;
  const context = await browser.newContext({
    ...(mobile ? devices['iPhone 14 Pro'] : { viewport: { width: 1366, height: 900 }, deviceScaleFactor: 1 }),
    userAgent: mobile ? undefined : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36',
    storageState: state && existsSync(state) ? state : undefined,
    locale: 'en-US',
  });
  const page = await context.newPage();
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
  await page.waitForTimeout(2500);
  // Dismiss common cookie/consent and login overlays when present.
  for (const sel of ['button:has-text("Accept")', 'button:has-text("I agree")', '[aria-label="close"]', 'button:has-text("Not now")']) {
    try { await page.locator(sel).first().click({ timeout: 800 }); } catch {}
  }
  return { browser, page };
}

async function scroll(page, times) {
  for (let i = 0; i < times; i++) {
    await page.mouse.wheel(0, 1600);
    await page.waitForTimeout(1200);
  }
}

async function collectImages(page, { max, min }) {
  const found = await page.evaluate((min) => {
    const best = (img) => {
      const set = img.getAttribute('srcset');
      if (set) {
        const parts = set.split(',').map((s) => s.trim().split(/\s+/));
        parts.sort((a, b) => parseFloat(b[1] || '0') - parseFloat(a[1] || '0'));
        return parts[0][0];
      }
      return img.currentSrc || img.src;
    };
    return [...document.images]
      .filter((i) => i.naturalWidth >= min || i.width >= min / 2)
      .map((i) => ({ src: best(i), alt: i.alt || '', w: i.naturalWidth, h: i.naturalHeight }))
      .filter((i) => i.src && i.src.startsWith('http'));
  }, min);
  const seen = new Set();
  const unique = found.filter((f) => (seen.has(f.src) ? false : seen.add(f.src)));
  const saved = [];
  for (const [n, img] of unique.slice(0, max).entries()) {
    try {
      const res = await page.request.get(img.src, { timeout: 20000 });
      if (!res.ok()) continue;
      const type = res.headers()['content-type'] || '';
      const ext = type.includes('png') ? 'png' : type.includes('webp') ? 'webp' : 'jpg';
      const file = join(out, `img-${String(n + 1).padStart(2, '0')}.${ext}`);
      writeFileSync(file, await res.body());
      saved.push({ file, ...img });
    } catch {}
  }
  return saved;
}

async function main() {
  const max = Number(flag('max', 24));
  const min = Number(flag('min', 300));
  let url;
  if (cmd === 'search') {
    const [site, ...q] = positional;
    if (!SEARCH[site]) throw new Error(`Unknown site ${site}. Try: ${Object.keys(SEARCH).join(', ')}`);
    url = SEARCH[site](q.join(' '));
  } else if (cmd === 'images' || cmd === 'shot') {
    url = positional[0];
  } else if (cmd === 'login') {
    console.error('login needs a desktop with a visible browser; run it locally and copy the state file.');
    const browser = await chromium.launch({ headless: false });
    const ctx = await browser.newContext();
    const p = await ctx.newPage();
    await p.goto(positional[0]);
    console.error('Sign in, then press Enter here.');
    await new Promise((r) => process.stdin.once('data', r));
    await ctx.storageState({ path: join(out, 'state.json') });
    await browser.close();
    console.log(join(out, 'state.json'));
    return;
  } else {
    console.log('usage: browse.mjs search <site> "<query>" | images <url> | shot <url>  [--max N] [--out DIR] [--mobile] [--scrolls N]');
    process.exit(1);
  }

  const { browser, page } = await open(url, { mobile: Boolean(flag('mobile', false)) });
  try {
    const scrolls = Number(flag('scrolls', cmd === 'shot' ? 2 : 3));
    const shots = [];
    await page.screenshot({ path: join(out, 'page-0.png') });
    shots.push(join(out, 'page-0.png'));
    if (cmd === 'shot') {
      for (let i = 1; i <= scrolls; i++) {
        await page.mouse.wheel(0, 900);
        await page.waitForTimeout(1000);
        const f = join(out, `page-${i}.png`);
        await page.screenshot({ path: f });
        shots.push(f);
      }
    } else {
      await scroll(page, scrolls);
    }
    const images = cmd === 'shot' ? [] : await collectImages(page, { max, min });
    const index = { url, title: await page.title(), finalUrl: page.url(), shots, images };
    writeFileSync(join(out, 'index.json'), JSON.stringify(index, null, 2));
    console.log(JSON.stringify({ out, title: index.title, finalUrl: index.finalUrl, shots: shots.length, images: images.length }, null, 2));
  } finally {
    await browser.close();
  }
}

main().catch((e) => {
  console.error(String(e?.message || e));
  process.exit(1);
});
