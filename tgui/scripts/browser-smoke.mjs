// Real Chromium + production bundle smoke. No BYOND process or external browser.
import { chromium } from 'playwright-core';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
const root = new URL('../../UI/tgui/', import.meta.url);
const js = await readFile(new URL('civ13-tgui.js', root));
const css = await readFile(new URL('civ13-tgui.css', root));
const html = '<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/civ13-tgui.css"></head><body><div id="root"></div><script>window.sent=[];window.Civ13Tgui={queue:[],send:function(type,payload){sent.push({type,payload})},ready:function(){window.ready=true},fallback:function(){window.fallback=true}};</script><script src="/civ13-tgui.js"></script></body></html>';
const server = createServer((req, res) => {
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
  if (process.env.SCREENSHOT_PATH) await page.screenshot({ path: process.env.SCREENSHOT_PATH, fullPage: true });
  await page.getByText('Classic interface', { exact: true }).click();
  assert.equal(await page.evaluate(() => window.fallback), true);
  assert.deepEqual(errors, []);
  console.log('PASS: production Chromium rendering, real tgui-core actions, safe text, canvas drag/found, research detail/assign/Escape, manual fallback');
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
