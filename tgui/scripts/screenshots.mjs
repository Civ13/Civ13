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
  await capture('chemistry', 'chem_disp.tmpl', { amount: 10, chemicals: ['Water', 'Carbon', 'Hydrogen', 'Oxygen', 'Nitrogen', 'Iron', 'Copper', 'Sulfur', 'Potassium', 'Sodium', 'Chlorine', 'Phosphorus'].map(title => ({ title, id: title.toLowerCase() })), isBeakerLoaded: 1, beakerCurrentVolume: 30, beakerMaxVolume: 100, beakerContents: [{ name: 'Water', volume: 20 }, { name: 'Carbon', volume: 10 }] });
  await capture('warehouse', 'warehouse_book.tmpl', { items: [{ name: 'Oak planks', amount: 120 }, { name: 'Stone blocks', amount: 84 }, { name: 'Iron ingots', amount: 36 }, { name: 'Linen cloth', amount: 52 }, { name: 'Wheat sacks', amount: 18 }] });
  // The rest of the windows, so a UI change can be compared before and after.
  const craftRow = (id, name, state, extra = {}) => ({ id, name, state, category: 'General', purpose: 'Building', pinned: 0, recent: 0, cost: '4 logs', why: '', tools: '', desc: '', built: 0, one_per_turf: 0, on_floor: 0, time: 140, makes: 1, batches: state === 'ready' ? 1 : 0, atlas: 0, image: '', ...extra });
  await capture('religion-list', 'religion_list.tmpl', { religions: [{ name: 'Sun Wardens', points: 340 }, { name: 'River Mothers', points: 215 }, { name: 'Order of the Ash', points: 90 }] });
  await capture('ship-stocks', 'ship_stocks.tmpl', { stocks: [['Treasury', 1240, 'reales'], ['Wood', 86, 'logs'], ['Cloth', 40, 'sheets'], ['Rope', 22, 'coils'], ['Food', 310, 'doses']].map(([label, amount, unit]) => ({ label, amount, unit })) });
  await capture('crew-log', 'crew_log.tmpl', { crew: [['Anne Hale', 'Captain'], ['Tom Reed', 'Boatswain'], ['Will Marsh', 'Sailor'], ['Edda Stone', 'Surgeon']].map(([name, job]) => ({ name, job })) });
  await capture('faction-list', 'faction_list.tmpl', { factions: [{ name: 'Dawnward Guild', motto: 'Build together', flavour: 'A fictional fellowship.', members: 4, symbol: '', renamed: '' }, { name: 'Ash Company', members: 1, symbol: '' }] });
  await capture('known-languages', 'known_languages.tmpl', { current_default: 'Common', languages: [{ name: 'Common', prefix: ',0', description: 'Spoken nearly everywhere.', is_default: 1 }, { name: 'Old Tongue', prefix: ',o', description: 'A scholarly language.' }] });
  await capture('prompt', 'prompt.tmpl', { message: 'The tide is coming in.', choices: ['Continue'] });
  await capture('vending', 'vending_machine2.tmpl', { company: 'Dawnward Trading', moneyin: 12, currency_name: 'silver', currency_short: 'sp', mode: 0, products: [{ key: 1, name: 'Bread loaf', price: 2, amount: 8 }, { key: 2, name: 'Iron hatchet', price: 14, amount: 1 }, { key: 3, name: 'Linen shirt', price: 6, amount: 0 }] });
  await capture('recruitment', 'recruitment_station.tmpl', {
    station: 1, bound: 1, supported: 1, faction: 'Dawnward Guild', motto: 'Build together, discover together', summary: 'Open to anyone who speaks Common and has Crafting 3.', expiry_days: 3, can_unbind: 1, can_review: 1,
    queue: [{ id: 4, name: 'Mara Flint', status: 'pending', status_text: 'Waiting for review', submitted: '2 hours', expires: '2 days', intro: 'I can smith and I have my own tools.', results: ['Speaks Common: met', 'Crafting 4/10, needs 3: met'] },
      { id: 5, name: 'Jon Weir', status: 'approved', status_text: 'Approved', submitted: '1 day', expires: '1 day', exception: 1, results: ['Speaks Common: met', 'Crafting 1/10, needs 3: not met'] }],
    policy: { mode: 'manual', open: 1, language: 'Common', nonmatch: 'review', skills: [{ key: 'crafting', label: 'Crafting', level: 3 }, { key: 'farming', label: 'Farming', level: 0 }] },
    audit: ['Leader set Crafting to 3 (1 day ago)'],
  });
  await capture('crafting', 'crafting_window.tmpl', { material: 'wood logs', unit: 'log', amount: 6, image: '', makeable_only: 0, categories: ['weapons', 'joinery'], purposes: ['Tools', 'Weapons', 'Building', 'Furniture', 'Other'], working: null, more_images: 0, rows: [
    craftRow('0:1:aaaaaaaa', 'campfire', 'ready', { built: 1, one_per_turf: 1, on_floor: 1, desc: 'A campfire made with wood logs.', atlas: 1 }),
    craftRow('2:1:bbbbbbbb', '3x arrow shaft', 'ready', { category: 'weapons', purpose: 'Weapons', cost: '1 log', makes: 3, batches: 6, time: 40 }),
    craftRow('0:2:cccccccc', 'travois', 'missing', { cost: '8 logs', why: 'Needs 8 logs, you have 6' }),
    craftRow('2:2:eeeeeeee', 'shortbow', 'locked', { category: 'weapons', purpose: 'Weapons', cost: '8 logs', why: 'Needs the Archery manual' }),
  ] });
  await capture('atlas', 'crafting_atlas.tmpl', { mode: 'graph', query: 'plank', era: '', processor: '', recipe_count: 2, resource_count: 1, recipes: [{ id: 'r2', name: 'Planks', era_label: '0: Stone Age' }, { id: 'r3', name: 'Plank wall', era_label: '0: Stone Age' }], resources: [{ id: 'wood_id', name: 'Wood log' }],
    detail: { id: 'r2', name: 'Planks', kind: 'Material / global', file: 'config/crafting/material_recipes_global.txt', line: 27, conditions: '', era_label: '0: Stone Age', era_basis: 'Research node', inputs: [{ id: '/material/wood', name: 'Log', quantity: '1', image: '' }], outputs: [{ id: '/obj/plank', name: 'Planks', quantity: '4', image: '' }], variants: [] } });
  assert.deepEqual(errors, []);
  await writeFile(`${output}/provenance.json`, JSON.stringify({ kind: 'cloud-browser-preview', nativeByondVerified: false, sourceHead: process.env.PREVIEW_SOURCE_HEAD || 'local', browser: browser.version(), viewport, deviceScaleFactor: 1, data: 'Deterministic fictional fixtures; no player or server data', shots }, null, 2) + '\n');
  console.log(`PASS: ${shots.length} production-bundle cloud previews captured; no browser errors`);
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
