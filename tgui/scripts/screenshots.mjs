// Real Chromium + production bundle previews of every window in src/fixtures.mts,
// with an index.html gallery. No BYOND process or external browser.
import { chromium } from 'playwright-core';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { screens } from '../src/fixtures.mts';
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
  const output = process.env.SCREENSHOT_DIR || 'screenshots';
  await mkdir(output, { recursive: true });
  const shots = [];
  // Every window from the shared fixtures, at the size the game opens it; taller content grows the capture.
  for (const { name, template, title, width, height, data } of screens) {
    await page.setViewportSize({ width, height });
    await page.evaluate(({ template, title, data }) => window.receiveUpdateData(JSON.stringify({ config: { template, title, status: 2 }, data })), { template, title, data });
    await page.waitForTimeout(300);
    const contentHeight = await page.locator('main').evaluate(el => Math.ceil(el.getBoundingClientRect().height));
    const captureViewport = { width, height: Math.max(height, contentHeight + 16) };
    await page.setViewportSize(captureViewport);
    await page.evaluate(() => { document.body.scrollTop = 0; });
    await page.screenshot({ path: `${output}/${name}.png`, fullPage: false, animations: 'disabled' });
    assert.equal(await page.evaluate(() => window.fallback === true), false, `${name} asked for the fallback`);
    assert.ok((await page.locator('main').innerText()).includes(title), `${name} did not render`);
    shots.push({ file: `${name}.png`, viewport: captureViewport, template, title, fixture: data });
  }
  const escape = value => String(value).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  await writeFile(`${output}/index.html`, `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Civ13 window previews</title>
<style>body{margin:0;padding:24px;background:#15120e;color:#eee5d3;font:15px/1.5 system-ui,sans-serif}h1{margin:0 0 4px}p{margin:0 0 20px;color:#bfae96}main{display:flex;flex-wrap:wrap;gap:24px;align-items:flex-start}figure{margin:0;max-width:100%}figcaption{margin-bottom:6px;font-weight:600}figcaption small{font-weight:400;color:#bfae96}img{display:block;max-width:100%;height:auto;border:1px solid #54432f}</style></head>
<body><h1>Civ13 window previews</h1><p>${shots.length} windows rendered from the production bundle with fictional fixtures. Browser previews only, not a BYOND client.</p><main>
${shots.map(shot => `<figure><figcaption>${escape(shot.title)} <small>${escape(shot.template)}, ${shot.viewport.width} x ${shot.viewport.height}</small></figcaption><img src="${escape(shot.file)}" width="${shot.viewport.width}" height="${shot.viewport.height}" alt="${escape(shot.title)} window preview" loading="lazy"></figure>`).join('\n')}
</main></body></html>
`);
  assert.deepEqual(errors, []);
  await writeFile(`${output}/provenance.json`, JSON.stringify({ kind: 'cloud-browser-preview', nativeByondVerified: false, sourceHead: process.env.PREVIEW_SOURCE_HEAD || 'local', browser: browser.version(), deviceScaleFactor: 1, data: 'Deterministic fictional fixtures; no player or server data', shots }, null, 2) + '\n');
  console.log(`PASS: ${shots.length} production-bundle cloud previews captured; no browser errors`);
} finally {
  await browser?.close();
  await new Promise(resolve => server.close(resolve));
}
