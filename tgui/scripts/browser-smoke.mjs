// Real Chromium + production bundle smoke. No BYOND process or external browser.
import { chromium } from 'playwright-core';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
const root = new URL('../../UI/tgui/', import.meta.url);
const js = await readFile(new URL('civ13-tgui.js', root));
const css = await readFile(new URL('civ13-tgui.css', root));
// Reuse the repository logo only as an explicit browser image fixture, not a
// captured in-game photo. Native resource delivery/cache are not exercised.
const photoPng = await readFile(new URL('../../UI/images/civ13.png', import.meta.url));
const html = '<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/civ13-tgui.css"></head><body><div id="root"></div><script>window.sent=[];window.Civ13Tgui={queue:[],acceptSnapshot:function(){return true},send:function(type,payload){sent.push({type,payload})},ready:function(){window.ready=true},fallback:function(){window.fallback=true}};</script><script src="/civ13-tgui.js"></script></body></html>';
const server = createServer((req, res) => {
  if (req.url === '/tmp_photo_12.png') { res.setHeader('Content-Type', 'image/png'); res.end(photoPng); return; }
  res.setHeader('Content-Type', req.url?.endsWith('.js') ? 'application/javascript' : req.url?.endsWith('.css') ? 'text/css' : 'text/html');
  res.end(req.url === '/civ13-tgui.js' ? js : req.url === '/civ13-tgui.css' ? css : html);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', headless: true });
  const page = await browser.newPage({ viewport: { width: 1000, height: 850 } });
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.waitForFunction(() => window.ready);
  const update = async (template, data, status = 2) => {
    await page.evaluate(({ template, data, status }) => window.receiveUpdateData(JSON.stringify({ config: { template, title: 'Civ13 UI', status }, data })), { template, data, status });
  };
  await update('chem_disp.tmpl', { amount: 5, chemicals: [{ title: 'Water', commands: { dispense: 'water' } }], isBeakerLoaded: 1, beakerContents: [] });
  await page.getByText('Water', { exact: true }).click();
  assert.deepEqual(await page.evaluate(() => window.sent.at(-1)), { type: 'act/dispense', payload: { dispense: 'water' } });
  await update('warehouse_book.tmpl', { items: [{ name: '&lt;img src=x onerror=alert(1)&gt;', amount: 4 }] });
  await page.getByText('<img src=x onerror=alert(1)>', { exact: true }).waitFor();
  assert.equal(await page.locator('img').count(), 0);
  await update('faction_creation.tmpl', { name: 'Test faction', grid: Array(1024).fill('#ffffff'), color: '#ff0000', tool: 'paint' });
  await page.getByRole('button', { name: 'Pixel 1,1', exact: true }).hover();
  await page.mouse.down();
  await page.getByRole('button', { name: 'Pixel 32,1', exact: true }).hover();
  await page.mouse.up();
  await page.waitForFunction(() => window.sent.some(item => item.type === 'act/stroke'));
  await page.waitForTimeout(300);
  await page.getByText('Found the faction', { exact: true }).click();
  assert.equal(await page.evaluate(() => window.sent.at(-1).type), 'act/found');
  await update('research_bench.tmpl', { bench_tier: 1, max_tier: 3, trees: [{ idx: 0, tree_name: 'Tools', layers: [{ layer_name: 'Ancient', nodes: [{ id: 'stone', name: 'Stone tools', status_text: 'Available', assignable: 1, recipe_names: ['Axe'], progress_percent: 25 }] }] }] });
  await page.getByText('Stone tools', { exact: true }).click();
  await page.getByRole('dialog').waitFor();
  await page.getByText('Assign this bench', { exact: true }).click();
  assert.deepEqual(await page.evaluate(() => window.sent.at(-1)), { type: 'act/assign', payload: { assign: 'stone' } });
  await page.keyboard.press('Escape');
  assert.equal(await page.getByRole('dialog').count(), 0);
  const atlas = { mode: 'graph', query: 'ore', era: '', processor: '', recipe_count: 1, resource_count: 1,
    resources: [{ id: '/material/ore', name: 'Indexed ore' }],
    recipes: [{ id: 'recipe-one', name: 'Fictional transformation', era_label: 'Context dependent' }],
    detail: { id: 'recipe-one', name: 'Fictional transformation', kind: 'Combine',
      inputs: [{ id: '/material/ore', name: 'Input ore', quantity: 2 }], outputs: [],
      conditions: 'Fictional browser data; map and skill requirements still apply.', file: 'code/game/fixture.dm', line: 12 } };
  await update('crafting_atlas.tmpl', atlas);
  await page.getByText('Indexed ore', { exact: true }).click();
  assert.deepEqual(await page.evaluate(() => window.sent.at(-1)), { type: 'act/atlas_navigate', payload: { atlas_navigate: JSON.stringify({ route: 'resource', resource: '/material/ore' }) } });
  const search = page.getByRole('searchbox', { name: 'Search', exact: true });
  await search.fill('draft');
  const beforeCancel = await page.evaluate(() => window.sent.length);
  await page.getByRole('button', { name: 'Cancel filter edits', exact: true }).click();
  assert.equal(await search.inputValue(), 'ore');
  assert.equal(await page.evaluate(() => window.sent.length), beforeCancel);
  await search.fill('new query');
  await page.getByRole('button', { name: 'Filter', exact: true }).click();
  assert.deepEqual(await page.evaluate(() => window.sent.at(-1)), { type: 'act/atlas_navigate', payload: { atlas_navigate: JSON.stringify({ route: 'open', query: 'new query', era: '', processor: '' }) } });
  await update('crafting_atlas.tmpl', atlas, 1);
  await page.getByRole('searchbox').waitFor();
  assert.equal(await search.isDisabled(), true);
  const beforeDisabled = await page.evaluate(() => window.sent.length);
  await page.getByText('Indexed ore', { exact: true }).dispatchEvent('click');
  assert.equal(await page.evaluate(() => window.sent.length), beforeDisabled);
  await update('crafting_atlas.tmpl', atlas);
  await page.getByRole('searchbox').waitFor();
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true);
  const flavorBefore = await page.evaluate(() => window.sent.length);
  await update('character_flavor.tmpl', { name: 'Fictional subject', text: 'First\n\u65e5\u672c\u8a9e \ud83d\ude00 &#10; &amp;lt;b&amp;gt; &lt;img src=x&gt;' }, 1);
  await page.getByRole('article', { name: 'Character description: Fictional subject' }).waitFor();
  assert.ok((await page.locator('article').textContent()).includes('\u65e5\u672c\u8a9e \ud83d\ude00 \n &lt;b&gt; <img src=x>'));
  assert.equal(await page.locator('article br').count(), 1);
  assert.equal(await page.locator('article img,article script,article a,article button,article input').count(), 0);
  assert.equal(await page.evaluate(() => window.sent.length), flavorBefore);
  await update('character_flavor.tmpl', { name: 'Second subject', text: '' }, 1);
  await page.getByRole('article', { name: 'Character description: Second subject' }).waitFor({ state: 'attached' });
  assert.equal(await page.locator('article').textContent(), '');
  const note = (text, bold = 0, italic = 0) => ({ text, bold, italic });
  const beforeNotes = await page.evaluate(() => window.sent.length);
  await update('character_notes.tmpl', { character: [note('Fictional reader')], sections: [{ title: [note('Role')], entries: [{ runs: [note('Guard', 1), { br: 1 }, note('the gate', 0, 1)] }] }], memory: [note('\u65e5\u672c\u8a9e \ud83d\ude00 &amp;lt;b&amp;gt; &lt;img src=x&gt;')], discoveries: [note('Discoveries', 1), { br: 1 }, note('Public observation')] }, 1);
  await page.getByText('You are Fictional reader', { exact: true }).waitFor();
  assert.equal(await page.locator('article button,article a,article input,article img,article script').count(), 0);
  assert.equal(await page.locator('article strong').count(), 3);
  assert.equal(await page.locator('article br').count(), 2);
  assert.ok((await page.locator('article').textContent()).includes('\u65e5\u672c\u8a9e \ud83d\ude00 &lt;b&gt; <img src=x>'));
  assert.equal(await page.evaluate(() => window.sent.length), beforeNotes);
  await update('character_notes.tmpl', { character: [note('Reopened reader')], sections: [], memory: [note('No memories stored.')], discoveries: [note('No discoveries recorded.')] }, 1);
  await page.getByText('You are Reopened reader', { exact: true }).waitFor();
  assert.equal(await page.getByText('Guard', { exact: true }).count(), 0);
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true);
  await update('photo_viewer.tmpl', { name: 'Fictional photo fixture', image: 'tmp_photo_12.png', width: 448, scribble: '&lt;script&gt;inert&lt;/script&gt; &amp; a boat.' }, 1);
  const photo = page.getByRole('img', { name: 'Photograph', exact: true });
  await photo.waitFor(); await page.waitForFunction(() => document.querySelector('.photo-viewer img')?.naturalWidth > 0);
  assert.equal(await photo.getAttribute('src'), 'tmp_photo_12.png');
  assert.equal(await photo.evaluate(image => image.width), 448);
  const photoBefore = await page.evaluate(() => window.sent.length);
  await photo.click(); assert.equal(await page.evaluate(() => window.sent.length), photoBefore);
  assert.equal(await page.locator('.photo-viewer button,.photo-viewer a,.photo-viewer script,.photo-viewer [onerror]').count(), 0);
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true);
  await page.getByText('<script>inert</script> & a boat.', { exact: true }).waitFor();
  await page.setViewportSize({ width: 360, height: 400 });
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true);
  assert.equal(await photo.evaluate(image => image.getBoundingClientRect().width <= image.parentElement.clientWidth), true);
  await update('photo_viewer.tmpl', { name: 'Empty photo', image: '', scribble: '' }, 1);
  await page.getByText('No captured image is available.', { exact: true }).waitFor();
  assert.equal(await page.locator('.photo-viewer img,.photo-viewer em').count(), 0);
  if (process.env.SCREENSHOT_PATH) await page.screenshot({ path: process.env.SCREENSHOT_PATH, fullPage: true });
  await page.getByText('Classic interface', { exact: true }).click();
  assert.equal(await page.evaluate(() => window.fallback), true);
  assert.deepEqual(errors, []);
  const invalid = await browser.newPage();
  await invalid.goto(`http://127.0.0.1:${server.address().port}`);
  await invalid.waitForFunction(() => window.ready);
  await invalid.evaluate(() => window.receiveUpdateData(JSON.stringify({ config: { template: 'character_flavor.tmpl', status: 1 }, data: { name: 'Fictional subject', text: 'PARTIAL\n<bad>' } })));
  await invalid.getByText('Switching to classic interface...', { exact: true }).waitFor();
  assert.equal(await invalid.evaluate(() => window.fallback), true);
  assert.ok(!(await invalid.locator('body').textContent()).includes('PARTIAL'));
  await invalid.close();
  console.log('PASS: production Chromium retained routes/actions, photo, Notes and flavor inert Unicode/read-only/replacement, manual and malformed fallback; fixtures, no native bridge/cache claim');
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
await import('./book-browser-smoke.mjs');
