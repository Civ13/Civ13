// Real Chromium + production bundle smoke. No BYOND process or external browser.
import { chromium } from 'playwright-core';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
const root = new URL('../../UI/tgui/', import.meta.url);
const js = await readFile(new URL('civ13-tgui.js', root));
const css = await readFile(new URL('civ13-tgui.css', root));
const html = '<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/civ13-tgui.css"></head><body><div id="root"></div><script>window.sent=[];window.Civ13Tgui={queue:[],acceptSnapshot:function(){return true},send:function(type,payload){sent.push({type,payload})},ready:function(){window.ready=true},fallback:function(){window.fallback=true}};</script><script src="/civ13-tgui.js"></script></body></html>';
const server = createServer((req, res) => {
  res.setHeader('Content-Type', req.url?.endsWith('.js') ? 'application/javascript' : req.url?.endsWith('.css') ? 'text/css' : 'text/html');
  res.end(req.url === '/civ13-tgui.js' ? js : req.url === '/civ13-tgui.css' ? css : html);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', headless: true });
  const viewport = { width: 1000, height: 850 };
  const page = await browser.newPage({ viewport, deviceScaleFactor: 1 });
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.waitForFunction(() => window.ready);
  const update = async (template, data, status = 2) => {
    await page.evaluate(({ template, data, status }) => window.receiveUpdateData(JSON.stringify({ config: { template, title: 'Civ13 - cloud preview', status }, data })), { template, data, status });
  };

  const output = process.env.SCREENSHOT_DIR || 'screenshots';
  await mkdir(output, { recursive: true });
  const shots = [];
  const capture = async (name, template, data) => {
    await update(template, data);
    await page.waitForTimeout(300);
    const contentHeight = await page.locator('main').evaluate(el => Math.ceil(el.getBoundingClientRect().height));
    const captureViewport = { width: 1000, height: Math.max(400, contentHeight + 16) };
    await page.setViewportSize(captureViewport);
    await page.evaluate(() => { document.body.scrollTop = 0; });
    await page.screenshot({ path: `${output}/${name}.png`, fullPage: false, animations: 'disabled' });
    shots.push({ file: `${name}.png`, viewport: captureViewport, template, fixture: data });
    await page.setViewportSize(viewport);
  };
  const node = (id, name, status_text, extra = {}) => ({ id, name, status_text, cost_ticks: 120, progress_percent: 0, era_tier: 1, min_bench_tier: 1, mode_text: 'Study', ...extra });
  await capture('research', 'research_bench.tmpl', {
    bench_tier: 2, max_tier: 3, bench_faction: 'Dawnward Guild', owns_bench: 1,
    has_faction: 1, viewer_role: 'Researcher', viewer_faction: 'Dawnward Guild', viewer_bench_count: 2, viewer_cap: 4,
    assigned_name: 'Bronze working', assigned_status_text: 'Study in progress - 55%', queue_names: ['Iron working'], can_queue: 1,
    trees: [{ idx: 0, tree_name: 'Craft and industry', layers: [
      { layer_name: 'Foundations', nodes: [node('stone', 'Stone tools', 'Done', { progress_percent: 100 }), node('clay', 'Pottery', 'Done', { grid_col: 3, progress_percent: 100 })] },
      { layer_name: 'Bronze age', nodes: [node('bronze', 'Bronze working', 'Available', { prereq_ids: 'stone', progress_percent: 55, assignable: 1, recipe_names: ['Bronze axe', 'Bronze spear'] }), node('kiln', 'Advanced kilns', 'Available', { grid_col: 3, prereq_ids: 'clay', queueable: 1 })] },
      { layer_name: 'Iron age', nodes: [node('iron', 'Iron working', 'Locked', { prereq_ids: 'bronze', is_era_changing: 1, cost_ticks: 240 }), node('masonry', 'Masonry', 'Locked', { grid_col: 3, prereq_ids: 'kiln' })] },
    ] }, { idx: 1, tree_name: 'Agriculture', layers: [] }],
  });
  const grid = Array.from({ length: 1024 }, (_, i) => {
    const x = i % 32, y = Math.floor(i / 32);
    if (x < 2 || x > 29 || y < 2 || y > 29) return '#d8ae58';
    if (Math.abs(x - 15.5) + Math.abs(y - 15.5) < 9) return '#f6d77f';
    return '#193c52';
  });
  await capture('faction', 'faction_creation.tmpl', { name: 'Dawnward Guild', motto: 'Build together, discover together', flavour: 'A fictional fellowship for this interface preview.', grid, color: '#f6d77f', tool: 'paint' });
  await capture('chemistry', 'chem_disp.tmpl', { amount: 10, chemicals: ['Water', 'Carbon', 'Hydrogen', 'Oxygen', 'Nitrogen', 'Iron', 'Copper', 'Sulfur', 'Potassium', 'Sodium', 'Chlorine', 'Phosphorus'].map(title => ({ title, commands: { dispense: title.toLowerCase() } })), isBeakerLoaded: 1, beakerCurrentVolume: 30, beakerMaxVolume: 100, beakerContents: [{ name: 'Water', volume: 20 }, { name: 'Carbon', volume: 10 }] });
  await capture('warehouse', 'warehouse_book.tmpl', { items: [{ name: 'Oak planks', amount: 120 }, { name: 'Stone blocks', amount: 84 }, { name: 'Iron ingots', amount: 36 }, { name: 'Linen cloth', amount: 52 }, { name: 'Wheat sacks', amount: 18 }] });
  assert.deepEqual(errors, []);
  await writeFile(`${output}/provenance.json`, JSON.stringify({ kind: 'cloud-browser-preview', nativeByondVerified: false, sourceHead: process.env.PREVIEW_SOURCE_HEAD || 'local', browser: browser.version(), viewport, deviceScaleFactor: 1, data: 'Deterministic fictional fixtures; no player or server data', shots }, null, 2) + '\n');
  console.log(`PASS: ${shots.length} production-bundle cloud previews captured; no browser errors`);
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
