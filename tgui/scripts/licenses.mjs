// Inventory all production dependencies (a conservative superset of bundled code).
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
const root = resolve(import.meta.dirname, '..');
const seen = new Map();
function visit(name) {
  if (seen.has(name)) return;
  const dir = resolve(root, 'node_modules', name);
  const pkg = JSON.parse(readFileSync(resolve(dir, 'package.json'), 'utf8'));
  const files = readdirSync(dir).filter(file => /^(licen[sc]e|copying)(\.|$)/i.test(file));
  if (!files.length) throw new Error(`Missing license for ${name}`);
  seen.set(name, { pkg, license: files.map(file => readFileSync(resolve(dir, file), 'utf8')).join('\n') });
  for (const dependency of Object.keys(pkg.dependencies ?? {})) visit(dependency);
}
for (const name of Object.keys(JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8')).dependencies)) visit(name);
let output = 'Civ13 tgui production dependency license inventory\n\nReference: tgstation/tgstation@bf6f771a1e221e06938978e36bbaf78543f85ebe\nCiv13 adaptation code: repository AGPL-3.0. No upstream game assets copied.\nThis inventory conservatively includes all production dependencies.\n';
for (const [name, { pkg, license }] of [...seen].sort(([a], [b]) => a.localeCompare(b))) {
  output += `\n${'='.repeat(72)}\n${name}@${pkg.version} (${pkg.license})\nhttps://www.npmjs.com/package/${name}/v/${pkg.version}\n\n${license}\n`;
}
writeFileSync(resolve(root, '../UI/tgui/THIRD_PARTY.txt'), output);
writeFileSync(resolve(root, 'THIRD_PARTY.md'), '# Third-party provenance\n\nThe build uses the official tgui6 component architecture, pinned to\n`tgstation/tgstation@bf6f771a1e221e06938978e36bbaf78543f85ebe`.\nNo upstream application files or game assets are copied. Civ13 screens and\ntransport are locally authored.\n\nComplete production-dependency license text and versions are generated in\n[`UI/tgui/THIRD_PARTY.txt`](../UI/tgui/THIRD_PARTY.txt) from installed locked\npackages by `node scripts/licenses.mjs`. React, React DOM and tgui-core source\nnotices are also retained in `licenses/`. The npm lockfile records integrity.\n');
