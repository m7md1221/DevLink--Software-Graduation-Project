// Computes WCAG contrast for every token pair and writes docs/design/contrast-report.md. Exits 1 if any pair fails.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { directions, pairs, ratio } from './tokens.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
let failures = 0;
const out = ['# Contrast report', '', 'Computed with the WCAG relative-luminance formula by `mockups/_src/contrast.mjs`. Minimums: 4.5:1 for text (1.4.3), 3:1 for control outlines and graphics (1.4.11).', ''];

for (const d of Object.values(directions)) {
  for (const mode of ['light', 'dark']) {
    const t = d[mode];
    if (!t) continue;
    out.push(`## ${d.name} — ${d.slug === 'c-signal' ? 'dark-first' : mode}`, '', '| Pair | Foreground | Background | Ratio | Needs | Result |', '|---|---|---|---|---|---|');
    for (const [fg, bg, min, what] of pairs) {
      const r = ratio(t[fg], t[bg]);
      const ok = r >= min;
      if (!ok) { failures++; console.log(`FAIL ${d.slug} ${mode} ${fg}/${bg} ${r.toFixed(2)} < ${min}`); }
      out.push(`| ${what} | \`${t[fg]}\` | \`${t[bg]}\` | ${r.toFixed(2)}:1 | ${min}:1 | ${ok ? 'pass' : '**FAIL**'} |`);
    }
    out.push('');
  }
}

fs.writeFileSync(path.join(here, '..', '..', 'contrast-report.md'), out.join('\n') + '\n');
console.log(failures ? `${failures} failing pair(s)` : 'all pairs pass');
process.exit(failures ? 1 : 0);
