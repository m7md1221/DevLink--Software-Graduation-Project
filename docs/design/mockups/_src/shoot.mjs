// Screenshots every mockup at desktop and phone width, and checks each page (playwright-style script for browser.mjs).
// node <browser.mjs> about:blank --script docs/design/mockups/_src/shoot.mjs
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const root = path.resolve('docs/design/mockups');
const shots = path.join(root, 'screenshots');
const VIEWPORTS = { desktop: { width: 1280, height: 860 }, phone: { width: 390, height: 844 } };
const ONLY = process.env.SHOOT_ONLY;

export default async function run(page) {
  fs.mkdirSync(shots, { recursive: true });
  const report = [];
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('requestfailed', (r) => errors.push('failed ' + r.url()));
  const external = [];
  page.on('request', (r) => { if (!r.url().startsWith('file:') && !r.url().startsWith('data:') && !r.url().startsWith('about:')) external.push(r.url()); });
  for (const dir of ['a-blueprint', 'b-zaytoun', 'c-signal']) {
    for (const lang of ['en', 'ar']) {
      for (const file of fs.readdirSync(path.join(root, dir, lang))) {
        const name = `${dir}-${lang}-${file.replace('.html', '')}`;
        if (ONLY && !name.includes(ONLY)) continue;
        for (const [vp, size] of Object.entries(VIEWPORTS)) {
          await page.setViewportSize(size);
          await page.goto(pathToFileURL(path.join(root, dir, lang, file)).href);
          await page.evaluate(() => document.fonts.ready);
          const facts = await page.evaluate(() => ({
            overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
            fonts: [...document.fonts].filter((f) => f.status === 'loaded').length,
            dir: document.documentElement.dir,
            arabicFont: document.fonts.check('16px ' + getComputedStyle(document.body).fontFamily.split(',')[0], 'م'),
            bidiReordered: [...document.querySelectorAll('bdi[dir=ltr]')].filter((b) => {
              const t = b.firstChild;
              if (!t || t.nodeType !== 3 || t.length < 2) return false;
              const x = (i) => { const r = document.createRange(); r.setStart(t, i); r.setEnd(t, i + 1); return r.getBoundingClientRect().left; };
              for (let i = 1; i < t.length; i++) if (x(i) < x(i - 1)) return true;
              return false;
            }).map((b) => b.textContent),
            bareNumbers: document.documentElement.lang !== 'ar' ? [] : (() => {
              const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
              const found = [];
              while (w.nextNode()) if (/(?<![A-Za-z])\d/.test(w.currentNode.data) && !w.currentNode.parentElement.closest('bdi')) found.push(w.currentNode.data);
              return found;
            })(),
            small: [...document.querySelectorAll('a.btn,button,.bottom-nav a')].filter((e) => { const r = e.getBoundingClientRect(); return r.width > 0 && (r.height < 24 || r.width < 24); }).length,
          }));
          // A fixed bar lands mid-page in a full-page capture, so it is drawn at the end of the page for the picture only.
          await page.addStyleTag({ content: '.bottom-nav{position:static!important}body{padding-block-end:0!important}' });
          await page.screenshot({ path: path.join(shots, `${name}-${vp}.png`), fullPage: true });
          report.push({ name, vp, ...facts });
        }
      }
    }
  }
  const bad = report.filter((r) => r.overflow > 0 || r.fonts === 0 || r.small > 0 || r.bidiReordered.length || r.bareNumbers.length);
  return { pages: report.length, problems: bad, errors: [...new Set(errors)].slice(0, 10), external: [...new Set(external)].slice(0, 10) };
}
