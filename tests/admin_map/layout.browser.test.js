// Exercises the legacy Browse HTML and canvas in runner Chromium, without BYOND.
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { pathToFileURL } = require('node:url');
const root = path.resolve(__dirname, '../..');
const modulePath = path.join(root, 'tgui/node_modules/playwright-core');
const lock = require(path.join(root, 'tgui/package-lock.json'));
assert.equal(require(path.join(modulePath, 'package.json')).version,
  lock.packages['node_modules/playwright-core'].version);
const { chromium } = require(modulePath);
const chrome = process.env.CHROMIUM_PATH;
const dir = process.env.ADMIN_MAP_TEST_TMP;
if (!chrome || !dir) throw new Error('Set CHROMIUM_PATH and ADMIN_MAP_TEST_TMP');
execFileSync('python3', [path.join(__dirname, 'export_browser_fixture.py'), dir], { cwd: root });

(async () => {
  const browser = await chromium.launch({
    executablePath: chrome, headless: true,
    args: ['--disable-background-networking', '--disable-extensions', '--disable-sync',
      '--host-resolver-rules=MAP * ~NOTFOUND'],
  });
  try {
    const url = pathToFileURL(path.join(dir, 'fixture.html')).href;
    const errors = [];
    const observations = [];
    const full = [1920, 1008];
    for (const dpr of [1, 1.25, 1.5, 2]) {
      const context = await browser.newContext({
        viewport: { width: full[0], height: full[1] },
        deviceScaleFactor: dpr,
      });
      await context.route('**/*', (route) =>
        route.request().url() === url ? route.continue() : route.abort());
      const page = await context.newPage();
      page.on('pageerror', (error) => errors.push(error.message));
      await page.goto(url);
      await page.getByLabel('Ghosts', { exact: true }).check();
      const search = page.getByPlaceholder('Search name or key');
      await search.fill('example');
      await search.press('End');
      let initial;
      for (const [width, height] of [full, [1366, 720], [430, 700], [1240, 320], full]) {
        await page.setViewportSize({ width, height });
        await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() =>
          requestAnimationFrame(resolve))));
        const b = await page.evaluate(() => {
          const rect = (id) => {
            const r = document.getElementById(id).getBoundingClientRect();
            return [r.left, r.top, r.width, r.height, r.right, r.bottom];
          };
          return { m: rect('m'), frame: rect('mapframe'), side: rect('side'), status: rect('s'),
            bitmap: [cv.width, cv.height, bg.width, bg.height], dpr: devicePixelRatio,
            pageWidth: Math.max(document.documentElement.scrollWidth, document.body.scrollWidth) };
        });
        observations.push({ width, height, ...b });
        assert.equal(b.dpr, dpr);
        assert.deepEqual(b.bitmap, [750, 528, 750, 528]);
        const [ml, mt, mw, mh, mr, mb] = b.m;
        const [fl, ft, fw, fh, fr, fb] = b.frame;
        assert(mw > 25 && mh > 25 && ml >= fl - 1 && mt >= ft - 1 &&
          mr <= fr + 1 && mb <= fb + 1, JSON.stringify(b));
        const fit = Math.min((fw - 4) / 750, (fh - 4) / 528);
        assert(Math.abs(mw - 4 - 750 * fit) < 1.1 && Math.abs(mh - 4 - 528 * fit) < 1.1,
          JSON.stringify(b));
        assert(b.side[0] >= fr + 8 && b.side[4] <= width && b.side[5] <= height + 1 &&
          b.pageWidth <= width && b.status[5] <= height + 1, JSON.stringify(b));
        if (width === full[0]) {
          if (initial) assert.deepEqual(b.m, initial);
          else assert(mw > 754 && mh > 532);
          initial ||= b.m;
        }
        async function tile(tx, ty) {
          const [x, y] = await page.evaluate(([tx, ty]) => {
            const r = cv.getBoundingClientRect();
            return [r.left + cv.clientLeft + (r.width - 2 * cv.clientLeft) * px(tx) / cv.width,
              r.top + cv.clientTop + (r.height - 2 * cv.clientTop) * py(ty) / cv.height];
          }, [tx, ty]);
          await page.mouse.click(x, y);
        }
        await tile(107, 125);
        assert.equal(await page.evaluate(() => SEL), 'fixture-player-one');
        await tile(204, 267);
        assert.equal(await page.evaluate(() => SYS), 8);
        await tile(430, 47);
        const [x, y] = await page.evaluate(() => AT);
        // A small view has fewer display pixels than tiles, so round to nearby tiles.
        assert(Math.abs(x - 430) <= 2 && Math.abs(y - 47) <= 2);
        assert(await page.getByLabel('Ghosts', { exact: true }).isChecked());
        assert.equal(await search.inputValue(), 'example');
        if ((dpr === 1 && width !== 1366) || (dpr === 1.5 && width === 1366)) {
          await page.screenshot({ path: path.join(dir, `admin-map-${width}x${height}-dpr-${dpr}.png`) });
        }
      }
      await context.close();
    }
    assert.deepEqual(errors, []);
    fs.writeFileSync(path.join(dir, 'browser-fit.json'), JSON.stringify({
      chromium: browser.version(), observations,
    }, null, 2));
    console.log('Passed 20 layouts: initial fit, shrink and expand, pointer hits, and retained controls at 100-200% DPR.');
  } finally {
    await browser.close();
  }
})().catch((error) => { console.error(error); process.exitCode = 1; });
