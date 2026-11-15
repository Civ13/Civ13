// Headless Chromium test of chat history carried across a reconnect, such as
// moving to another region; no server or BYOND. The page is loaded, fed
// fictional lines, then reloaded to stand in for the new world's fresh page.
// Set CHROME_BIN (or CHROMIUM_PATH) and CHAT_TEST_TMP. CHAT_SCREENSHOT=<path>
// also saves a picture of the restored chat.
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
const dir = fs.mkdtempSync(path.join(scratch, 'chat-history-'));
const fixture = path.join(dir, 'fixture.html');
fs.writeFileSync(fixture, html);
for (const name of ['Alegreya-Regular.ttf', 'Alegreya-Bold.ttf', 'Alegreya-Italic.ttf', 'Alegreya-BoldItalic.ttf', 'Alegreya-Black.ttf', 'Wizard.ttf']) {
  fs.copyFileSync(path.join(root, 'interface/fonts', name), path.join(dir, name));
}
fs.copyFileSync(path.join(root, 'code/js/purify.min.js'), path.join(dir, 'purify.min.js'));

const say = s => encodeURIComponent(s);
const failures = [];
const check = (ok, label) => { if (!ok) failures.push(label); };
const KEY = 'civ13-chat-history-v1:';

(async function () {
  let context, closeOk = false;
  const errors = [];
  try {
    context = await chromium.launchPersistentContext(path.join(dir, 'profile'), {
      executablePath: chrome, headless: true, viewport: { width: 520, height: 420 },
      timeout: 15000,
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
    const lines = () => page.evaluate(() => Array.from(document.querySelectorAll('#messages .message')).map(m => ({
      text: m.textContent, type: m.getAttribute('data-chat-type'), restored: m.classList.contains('restored'),
      divider: m.classList.contains('chat-history-divider'), shown: getComputedStyle(m).display !== 'none' })));

    // First world: nothing stored yet, so no divider.
    await load();
    await page.evaluate(() => localStorage.clear());
    await page.evaluate(() => window.setChatIdentity('alice'));
    check((await lines()).length === 0, 'first connection restores nothing');
    await page.evaluate(msgs => msgs.forEach(m => window.receiveMessage(m)), [
      say("<span class='say'><span class='name'>Ada</span> says, \"The river is rising.\"</span>"),
      say("<span class='ooc'><span class='prefix'>OOC:</span> Bo: heading to North</span>"),
      say("<span class='deadsay'>DEAD: an old ghost waves</span>"),
      say("<span class='notice'>You see <a href='?src=[0x2000123];look=1'>a spear</a> and <a href='https://civ13.com'>the site</a>.</span>"),
    ]);
    for (let i = 0; i < 300; i++) await page.evaluate(n => window.receiveMessage(encodeURIComponent("<span class='radio'>[Radio] check " + n + '</span>')), i);
    // Before the debounce runs, leaving the page must still save.
    await page.evaluate(() => window.receiveMessage(encodeURIComponent("<span class='say'>Bo says, \"Last words here.\"</span>")));

    // Second world: a fresh page, told the same ckey.
    await load();
    const stored = await page.evaluate(k => localStorage.getItem(k), KEY + 'alice');
    check(!!stored, 'history saved under the ckey on leaving');
    if (stored) {
      const parsed = JSON.parse(stored);
      check(parsed.lines.length <= 400, 'saved lines capped [' + parsed.lines.length + ']');
      check(parsed.lines.filter(l => l.t === 'radio').length <= 120, 'busy type capped in storage');
      check(parsed.lines.some(l => l.t === 'dead'), 'quiet types survive a flood');
    }
    await page.evaluate(() => window.receiveMessage(encodeURIComponent("<span class='notice'>Welcome to North America.</span>")));
    await page.evaluate(() => window.setChatIdentity('alice'));
    let now = await lines();
    const dividerAt = now.findIndex(l => l.divider);
    check(dividerAt > 0, 'divider follows the restored lines [' + dividerAt + ']');
    check(now.slice(0, dividerAt).every(l => l.restored), 'restored lines sit above the divider');
    check(now[now.length - 1].text.includes('Welcome to North America'), 'new world output stays below');
    check(now.some(l => l.restored && l.text.includes('The river is rising') && l.type === 'ic'), 'IC line restored with its type');
    check(now.some(l => l.restored && l.text.includes('Last words here')), 'line sent just before leaving restored');
    check(now.some(l => l.restored && l.type === 'dead'), 'dead chat restored');
    const links = await page.evaluate(() => Array.from(document.querySelectorAll('.message.restored a')).map(a => [a.textContent, a.getAttribute('href')]));
    check(links.some(([t, h]) => t === 'a spear' && h === null), 'game link from the old world disabled');
    check(links.some(([t, h]) => t === 'the site' && h === 'https://civ13.com'), 'web link kept');
    const badges = await page.evaluate(() => document.querySelectorAll('.chat-tab .unread').length);
    check(badges === 0, 'restored lines do not count as unread [' + badges + ']');

    // Tab filters apply to restored lines; the divider shows everywhere.
    await page.evaluate(() => Array.from(document.querySelectorAll('.chat-tab')).find(b => b.firstChild.nodeValue === 'Dead').click());
    now = await lines();
    check(now.filter(l => l.shown && l.restored).every(l => l.type === 'dead'), 'Dead tab hides other restored lines');
    check(now.some(l => l.divider && l.shown), 'divider shows on every tab');
    await page.evaluate(() => Array.from(document.querySelectorAll('.chat-tab')).find(b => b.firstChild.nodeValue === 'All').click());
    const atTail = await page.evaluate(() => { const c = document.getElementById('chat-container'); return c.scrollHeight - c.clientHeight - c.scrollTop <= 2; });
    check(atTail, 'scrolled to the newest line after restoring');
    if (process.env.CHAT_SCREENSHOT) await page.screenshot({ path: process.env.CHAT_SCREENSHOT });

    // A second identity call does nothing; another ckey gets nothing.
    await page.evaluate(() => window.setChatIdentity('alice'));
    check((await lines()).filter(l => l.divider).length === 1, 'restored only once per page');
    await load();
    await page.evaluate(() => window.setChatIdentity('carol'));
    check((await lines()).length === 0, 'another ckey sees no history');

    // Stored markup is sanitized again; scripts and handlers never run.
    await page.evaluate(k => localStorage.setItem(k, JSON.stringify({ savedAt: Date.now(), lines: [
      { t: 'ic', h: '<img src=x onerror="window.__pwned=1"><span>hi</span><script>window.__pwned=2</script>' },
      { t: 'bogus', h: '<form action="byond://?x=1"><button>go</button></form>plain' },
      { t: 'ic', h: 42 },
    ] })), KEY + 'dave');
    await load();
    await page.evaluate(() => window.setChatIdentity('dave'));
    await page.waitForTimeout(100);
    check(!(await page.evaluate(() => window.__pwned)), 'stored markup cannot run script');
    now = await lines();
    check(now.some(l => l.restored && l.type === 'other' && l.text.endsWith('plain')), 'unknown type becomes other and forms are dropped');
    check(!(await page.evaluate(() => document.querySelector('#messages form, #messages button'))), 'no forms or buttons restored');

    // Old history expires; Clear Chat wipes it.
    await page.evaluate(k => localStorage.setItem(k, JSON.stringify({ savedAt: Date.now() - 2 * 86400000, lines: [{ t: 'ic', h: 'stale' }] })), KEY + 'erin');
    await load();
    await page.evaluate(() => window.setChatIdentity('erin'));
    check((await lines()).length === 0, 'history older than a day is ignored');
    await load();
    await page.evaluate(() => { window.setChatIdentity('alice'); window.clearChat(); });
    await load();
    await page.evaluate(() => window.setChatIdentity('alice'));
    check((await lines()).length === 0, 'Clear Chat also clears the saved history');

    // Malformed storage and bad ckeys are ignored.
    await page.evaluate(k => localStorage.setItem(k, '{not json'), KEY + 'frank');
    await load();
    await page.evaluate(() => { window.setChatIdentity('../frank'); window.setChatIdentity('frank'); });
    check((await lines()).length === 0, 'malformed history ignored');

    if (errors.length) failures.push('page errors: ' + errors.join(' | '));
    if (failures.length) throw new Error('Browser assertion: ' + failures.join(' | '));
    console.log('PASS chat history browser cases; evidence: ' + dir);
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
