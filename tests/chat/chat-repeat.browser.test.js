// Headless Chromium test of repeated chat lines; no server or BYOND. An
// identical message straight after the last line adds an ×2, ×3 counter to
// that line; any other line in between starts a new one.
// Set CHROME_BIN (or CHROMIUM_PATH) and CHAT_TEST_TMP. CHAT_SCREENSHOT=<path>
// also saves a picture of the counters.
'use strict';
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const chrome = process.env.CHROME_BIN || process.env.CHROMIUM_PATH;
const scratch = process.env.CHAT_TEST_TMP;
if (!chrome || !scratch) throw new Error('Set CHROME_BIN (or CHROMIUM_PATH) and CHAT_TEST_TMP');
fs.mkdirSync(scratch, { recursive: true });
process.env.TMPDIR = scratch; process.env.TEMP = scratch; process.env.TMP = scratch;
const root = path.resolve(__dirname, '../..');
const modulePath = process.env.PLAYWRIGHT_CORE_PATH || path.join(root, 'tgui/node_modules/playwright-core');
const lock = JSON.parse(fs.readFileSync(path.join(root, 'tgui/package-lock.json'), 'utf8'));
const pinned = lock.packages['node_modules/playwright-core'].version;
const installed = JSON.parse(fs.readFileSync(path.join(modulePath, 'package.json'), 'utf8')).version;
if (installed !== pinned) throw new Error('playwright-core does not match the repository lock');
const { chromium } = require(modulePath);
let html = fs.readFileSync(path.join(root, 'interface/chat/chat.html'), 'utf8');
const bridge = "window.location.href = 'byond://?chat_ready=1';";
if (html.split(bridge).length !== 2) throw new Error('Chat ready bridge anchor changed');
html = html.replace(bridge, 'window.__chatTestReady = true;');
const dir = fs.mkdtempSync(path.join(scratch, 'chat-repeat-'));
const fixture = path.join(dir, 'fixture.html');
fs.writeFileSync(fixture, html);
for (const name of ['Alegreya-Regular.ttf', 'Alegreya-Bold.ttf', 'Alegreya-Italic.ttf', 'Alegreya-BoldItalic.ttf', 'Alegreya-Black.ttf', 'Wizard.ttf']) {
  fs.copyFileSync(path.join(root, 'interface/fonts', name), path.join(dir, name));
}
fs.copyFileSync(path.join(root, 'code/js/purify.min.js'), path.join(dir, 'purify.min.js'));

const say = s => encodeURIComponent(s);
const failures = [];
const check = (ok, label) => { if (!ok) failures.push(label); };

(async function () {
  let context, closeOk = false;
  const errors = [];
  try {
    context = await chromium.launchPersistentContext(path.join(dir, 'profile'), {
      executablePath: chrome, headless: true, viewport: { width: 520, height: 300 },
      timeout: 15000,
      args: ['--disable-background-networking', '--disable-extensions', '--disable-sync', '--host-resolver-rules=MAP * ~NOTFOUND'],
    });
    await context.route('**/*', route => {
      const protocol = new URL(route.request().url()).protocol;
      return protocol === 'file:' || protocol === 'data:' ? route.continue() : route.abort();
    });
    const page = context.pages()[0] || await context.newPage();
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(pathToFileURL(fixture).href, { waitUntil: 'load', timeout: 15000 });
    await page.waitForFunction(() => window.__chatTestReady === true, null, { timeout: 15000 });
    await page.evaluate(() => localStorage.clear());
    const lines = () => page.evaluate(() => Array.from(document.querySelectorAll('#messages .message')).map(m => {
      const badge = m.querySelector('.chat-repeat');
      return { text: m.textContent, badge: badge ? badge.textContent : '', badges: m.querySelectorAll('.chat-repeat').length,
        type: m.getAttribute('data-chat-type') };
    }));
    // Messages more than the page's 100 ms glitch filter apart.
    const send = async m => { await page.evaluate(x => window.receiveMessage(x), say(m)); await page.waitForTimeout(120); };
    const tabs = () => page.evaluate(() => Array.from(document.querySelectorAll('.chat-tab')).map(b => b.textContent));

    const warn = "<span class='warning'>You don't know how to do this yet. Study the <b>Steelmaking</b> chapter first.</span>";
    await send(warn);
    let now = await lines();
    check(now.length === 1 && now[0].badge === '', 'a first message has no counter');
    await send(warn);
    await send(warn);
    now = await lines();
    check(now.length === 1, 'identical messages stay on one line');
    check(now[0].badge === '×3' && now[0].badges === 1, 'the counter reads ×3 after three copies');

    // A different message interrupts the run; the same one again starts fresh.
    await send("<span class='say'>Ada says, \"Need a hand?\"</span>");
    await send(warn);
    now = await lines();
    check(now.length === 3 && now[2].badge === '', 'a repeat after another message is a new line');
    check(now[0].badge === '×3', 'the earlier counter is kept');
    await send(warn);
    now = await lines();
    check(now.length === 3 && now[2].badge === '×2', 'the new line counts on its own');

    // Similar is not identical.
    await send("<span class='warning'>You don't know how to do this yet. Study the <b>Bronze Working</b> chapter first.</span>");
    now = await lines();
    check(now.length === 4 && now[3].badge === '', 'a different warning is a new line');

    // A counted line still filters by type and raises unread on other tabs.
    const say1 = "<span class='ooc'><span class='prefix'>OOC:</span> Bo: brb</span>";
    await send(say1);
    const before = await tabs();
    await send(say1);
    now = await lines();
    check(now.length === 5 && now[4].badge === '×2' && now[4].type === 'ooc', 'OOC repeats count and keep their type');
    const after = await tabs();
    check(JSON.stringify(before) !== JSON.stringify(after), 'a repeat updates unread counts on other tabs');

    // A connection notice between two copies breaks the run.
    await page.evaluate(() => {
      const div = document.createElement('div');
      div.className = 'message connection-notice';
      document.getElementById('messages').appendChild(div);
    });
    await send(say1);
    now = await lines();
    check(now[now.length - 1].badge === '' && now[now.length - 1].type === 'ooc', 'a notice in between starts a new line');

    // Clear Chat resets the run.
    await page.evaluate(() => window.clearChat());
    await send(say1);
    now = await lines();
    check(now.length === 1 && now[0].badge === '', 'after Clear Chat the same message is a new line');

    await page.evaluate(() => window.clearChat());
    await send("<span class='notice'>Tick</span>");
    for (let i = 0; i < 11; i++) await send("<span class='notice'>Tick</span>");
    now = await lines();
    check(now.length === 1 && now[0].badge === '×12', 'counts past ten');

    // The game sends an ordered batch, not seven coincident messages.
    await page.evaluate(() => window.clearChat());
    const shovel = [
      '<font size=1>You look at the bone shovel.</font>',
      "That's a bone shovel.",
      'A shovel made out of some bone.',
      '<b>Material:</b> bone - unremarkable.',
      '<b>Components:</b> bone head (quality 1), wood handle (quality 1).',
      '<b>Quality:</b> Decent',
      "<font color='#245319'>Seems to be in very good condition.</font>",
    ];
    const examine = (id, batch) => page.evaluate(
      args => window.receiveExamine(encodeURIComponent(JSON.stringify({ id: String(args.id), lines: args.batch }))),
      { id: typeof id === 'number' ? 'first-world:' + id : id, batch },
    );
    await examine(1, shovel);
    await examine(1, shovel);
    now = await lines();
    check(now.length === 1 && now[0].badge === '', 'a duplicate delivery does not count');
    await examine(2, shovel);
    await examine(3, shovel);
    now = await lines();
    check(now.length === 1 && now[0].badge === '×3' && now[0].badges === 1, 'rapid distinct examines of the same block count');
    const blockLines = () => page.locator('#messages .chat-examine').first().locator('div').allTextContents();
    check(JSON.stringify(await blockLines()) === JSON.stringify([
      'You look at the bone shovel.', "That's a bone shovel.", 'A shovel made out of some bone.',
      'Material: bone - unremarkable.', 'Components: bone head (quality 1), wood handle (quality 1).',
      'Quality: Decent', 'Seems to be in very good condition.',
    ]), 'all seven shovel lines are preserved in order');
    const worn = shovel.slice(0, -1).concat('The shovel is worn.');
    await examine(4, worn);
    now = await lines();
    check(now.length === 2 && now[1].badge === '', 'one changed line starts a new block');
    await send("<span class='ooc'>Someone says something.</span>");
    await examine(5, worn);
    now = await lines();
    check(now.length === 4 && now[3].badge === '', 'interleaved output breaks the run even across tabs');
    await examine(6, ['private examine', "<span class='ooc'>a mixed tab</span>"]);
    now = await lines();
    check(now.length === 6 && now[4].type === 'other' && now[5].type === 'ooc', 'mixed channels stay separate');
    await examine(7, ['safe', "<img src=x onerror='window.__chatUnsafe = true'>"]);
    check(await page.locator('.chat-examine [onerror]').count() === 0, 'batch content goes through sanitization');
    await examine(8, shovel);
    await examine('new-world:1', shovel);
    now = await lines();
    check(now.length === 9 && now[8].badge === '', 'a new world can restart its delivery sequence without sharing counters');

    if (process.env.CHAT_SCREENSHOT) {
      await page.evaluate(() => window.clearChat());
      await send("<span class='say'><span class='name'>Ada</span> says, \"The river is rising.\"</span>");
      for (let i = 0; i < 4; i++) await send(warn);
      await send("<span class='notice'>You pick up the iron ingot.</span>");
      await send("<span class='warning'>You don't know how to do this yet. Study the <b>Steelmaking or Tatara Smelting</b> chapter first.</span>");
      await send("<span class='warning'>You don't know how to do this yet. Study the <b>Steelmaking or Tatara Smelting</b> chapter first.</span>");
      await send("<span class='ooc'><span class='prefix'>OOC:</span> <span class='name'>Bo</span>: lag?</span>");
      await page.waitForTimeout(400);
      await page.screenshot({ path: process.env.CHAT_SCREENSHOT });
    }

    if (errors.length) failures.push('page errors: ' + errors.join(' | '));
    if (failures.length) throw new Error('Browser assertion: ' + failures.join(' | '));
    console.log('PASS chat repeat browser cases; evidence: ' + dir);
  } catch (err) {
    console.error(String(err) + '; evidence: ' + dir);
    process.exitCode = 1;
  } finally {
    if (context) {
      try { await context.close(); closeOk = true; } catch (err) { console.error('Browser cleanup failed: ' + err); process.exitCode = 1; }
    }
    fs.writeFileSync(path.join(dir, 'browser.cleanup.json'), JSON.stringify({ contextClosed: closeOk, failures, errors }));
  }
})().catch(err => { console.error(err); process.exitCode = 1; });
