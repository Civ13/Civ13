// Headless Chromium test of the Plain chat text switch; no server or BYOND.
// Names on OOC lines are bold and upright; with the switch on, no chat line
// is italic or underlined, and the choice survives a reload.
// Set CHROME_BIN (or CHROMIUM_PATH) and CHAT_TEST_TMP. CHAT_SCREENSHOT=<path>
// saves a picture; CHAT_PLAIN=1 takes it with the switch on.
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
const dir = fs.mkdtempSync(path.join(scratch, 'chat-plain-'));
const fixture = path.join(dir, 'fixture.html');
fs.writeFileSync(fixture, html);
for (const name of ['Alegreya-Regular.ttf', 'Alegreya-Bold.ttf', 'Alegreya-Italic.ttf', 'Alegreya-BoldItalic.ttf', 'Alegreya-Black.ttf', 'Wizard.ttf']) {
  fs.copyFileSync(path.join(root, 'interface/fonts', name), path.join(dir, name));
}
fs.copyFileSync(path.join(root, 'code/js/purify.min.js'), path.join(dir, 'purify.min.js'));


const say = s => encodeURIComponent(s);
const failures = [];
const check = (ok, label) => { if (!ok) failures.push(label); };
const sample = [
  "<span class='ooc'><span class='everyone'><span class='prefix'>OOC:</span> <EM>Bo:</EM> <span class='message chat-tr'>anyone near the river?</span></span></span>",
  "<span class='emote'><b>Ada</b> <span class='chat-tr'>waves at the ferry.</span></span>",
  "<span class='warning'>You cannot reach that. See the <a href='https://example.invalid/guide'>building guide</a>.</span>",
  "<span class='ghostalert'>A ship is leaving. <a href='https://example.invalid/follow'>Follow</a></span>",
  "<span class='say'><span class='name'>Ada</span> says, \"The <i>old</i> bridge is <u>out</u>.\"</span>",
  "<span class='notice'>You pick up the iron ingot.</span>",
];

(async function () {
  let context, closeOk = false;
  const errors = [];
  try {
    const small = !!process.env.CHAT_SMALL;
    context = await chromium.launchPersistentContext(path.join(dir, 'profile'), {
      executablePath: chrome, headless: true, viewport: { width: small ? 360 : 520, height: small ? 190 : 300 },
      deviceScaleFactor: Number(process.env.CHAT_DPR) || 1, timeout: 15000,
      args: ['--disable-background-networking', '--disable-extensions', '--disable-sync', '--host-resolver-rules=MAP * ~NOTFOUND'],
    });
    await context.route('**/*', route => {
      const protocol = new URL(route.request().url()).protocol;
      return protocol === 'file:' || protocol === 'data:' ? route.continue() : route.abort();
    });
    const page = context.pages()[0] || await context.newPage();
    page.on('pageerror', error => errors.push(error.message));
    const load = async () => {
      await page.goto(pathToFileURL(fixture).href, { waitUntil: 'load', timeout: 15000 });
      await page.waitForFunction(() => window.__chatTestReady === true, null, { timeout: 15000 });
    };
    const feed = () => page.evaluate(msgs => msgs.forEach(m => window.receiveMessage(m)), sample.map(say));
    // Every element in the chat lines with its computed italic and underline.
    const styles = () => page.evaluate(() => Array.from(document.querySelectorAll('#messages *')).map(el => {
      const cs = getComputedStyle(el);
      return { tag: el.tagName, cls: el.className, italic: cs.fontStyle !== 'normal', line: cs.textDecorationLine !== 'none', weight: Number(cs.fontWeight), color: cs.color };
    }));
    const setPlain = on => page.evaluate(v => { const box = document.getElementById('chat-plain-on'); box.checked = v; box.dispatchEvent(new Event('change')); }, on);

    await load();
    await page.evaluate(() => localStorage.clear());
    await load();
    await feed();

    // Default: off. Names are bold upright; emotes, warnings and links keep their look.
    check(!(await page.evaluate(() => document.getElementById('chat-plain-on').checked)), 'plain text is off by default');
    check(!(await page.evaluate(() => document.body.classList.contains('chat-plain'))), 'no plain class by default');
    let now = await styles();
    const em = now.filter(s => s.tag === 'EM');
    check(em.length === 1 && !em[0].italic && em[0].weight >= 700, 'OOC name is bold and not italic: ' + JSON.stringify(em));
    check(now.some(s => s.cls === 'emote' && s.italic), 'emotes are italic by default');
    check(now.some(s => s.tag === 'A' && s.line && s.italic), 'a link in a warning is italic and underlined by default');
    const linkColor = now.find(s => s.tag === 'A').color;

    // On: nothing in the chat lines is italic or underlined; links keep their colour.
    await setPlain(true);
    now = await styles();
    check(now.length > 10 && !now.some(s => s.italic), 'no italics with plain text on: ' + JSON.stringify(now.filter(s => s.italic)));
    check(!now.some(s => s.line), 'no underlines with plain text on: ' + JSON.stringify(now.filter(s => s.line)));
    check(now.find(s => s.tag === 'A').color === linkColor && linkColor !== now.find(s => s.cls === 'notice').color, 'links keep their own colour');
    check(now.some(s => s.cls === 'name' && s.weight >= 700), 'bold stays');
    check(await page.evaluate(() => localStorage.getItem('civ13-chat-plain-v1')) === '1', 'turning it on is saved');

    // New lines and a reload keep it.
    await feed();
    now = await styles();
    check(!now.some(s => s.italic || s.line), 'lines arriving later are plain too');
    await load();
    check(await page.evaluate(() => document.getElementById('chat-plain-on').checked && document.body.classList.contains('chat-plain')), 'stays on after a reload');
    await feed();
    check(!(await styles()).some(s => s.italic || s.line), 'plain after a reload');

    // Off again restores the normal look and is saved.
    await setPlain(false);
    now = await styles();
    check(now.some(s => s.cls === 'emote' && s.italic) && now.some(s => s.tag === 'A' && s.line), 'turning it off restores italics and underlines');
    check(await page.evaluate(() => localStorage.getItem('civ13-chat-plain-v1')) === '0', 'turning it off is saved');
    // The settings panel is not affected by the switch.
    await setPlain(true);
    check(await page.evaluate(() => getComputedStyle(document.querySelector('#chat-settings h3')).fontStyle) === 'normal', 'settings panel unchanged');

    if (process.env.CHAT_SCREENSHOT) {
      await setPlain(!!process.env.CHAT_PLAIN);
      await page.evaluate(() => window.clearChat());
      await feed();
      if (process.env.CHAT_SETTINGS) await page.click('#chat-tab-settings');
      await page.waitForTimeout(400);
      await page.screenshot({ path: process.env.CHAT_SCREENSHOT });
    }

    if (errors.length) failures.push('page errors: ' + errors.join(' | '));
    if (failures.length) throw new Error('Browser assertion: ' + failures.join(' | '));
    console.log('PASS chat plain text browser cases; evidence: ' + dir);
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
