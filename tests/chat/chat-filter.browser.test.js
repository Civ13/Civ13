// Headless Chromium test of the chat filter tabs on the actual chat page; no
// server or BYOND. Set CHROME_BIN (or CHROMIUM_PATH) and CHAT_TEST_TMP.
// CHAT_SCREENSHOT=<path> also saves a picture of the tab bar and settings.
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

// Messages mirror the markup the game sends (see code/__defines/chat.dm CHAT_TYPED).
const script = String.raw`
(async function () {
    const failures = [];
    const check = (ok, label) => { if (!ok) failures.push(label); };
    const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
    const add = (id, text) => window.receiveMessage(encodeURIComponent(text + '<span id="' + id + '"></span>'));
    const typeOf = id => { const n = document.getElementById(id); return n && n.closest('.message').getAttribute('data-chat-type'); };
    const shown = id => { const n = document.getElementById(id); return !!n && !n.closest('.message').classList.contains('filtered'); };
    const tabs = () => Array.from(document.querySelectorAll('.chat-tab')).map(b => b.firstChild.nodeValue);
    const tabButton = name => Array.from(document.querySelectorAll('.chat-tab')).find(b => b.firstChild.nodeValue === name);
    try {
        check(window.__chatTestReady, 'chat initialization');
        check(tabs().join(',') === 'All,IC,Radio,OOC,Dead', 'default tabs, Admin hidden [' + tabs().join(',') + ']');

        add('m-say', "<span class='chattype-ic'><span class='name'>Bob</span> says, \"hi\"</span>");
        add('m-radio', "<span class='chattype-radio'><font color=#FFAE19><b>Radio (150 kHz):</b></font> <b>Bob</b> \"over\"</span>");
        add('m-ooc', "<span class='ooc'><span class='everyone'>OOC: <em>val:</em> <span class='message'>hello</span></span></span>");
        add('m-looc', "<span class='ooc'><span class='looc'>LOOC: <em>val:</em> hi</span></span>");
        add('m-dead', "<span class='chattype-dead'>DEAD: <span style='color: #8657C5'> boo</span></span>");
        add('m-deadtag', "<span class='text_tag tag-dead'>DEAD</span><span> boo</span>");
        add('m-lobby', "<span class='chattype-ooc'>LOBBY: <span class='deadsay'><b>Val</b>:</span> hi</span>");
        add('m-pm', "<span class='pm'><span class='in'><b>[Admin PM]</b> <span class='message'>hi</span></span></span>");
        add('m-emote', "<span class='chattype-ic'><b>Bob</b> waves.</span>");
        add('m-whisper', "<i><span class='game say'>Common, <span class='name'>Bob</span> whispers</span></i>");
        add('m-warn', "<span class='danger'>Bob hits you!</span>");
        add('m-examine', "This is Bob.\n<span class='deadsay'>He is asleep.</span>");
        add('m-plain', 'You pick up the axe.');
        add('m-bogus', "<span class='chattype-nonsense'>odd</span>");
        await delay(50);
        const expected = { 'm-say': 'ic', 'm-radio': 'radio', 'm-ooc': 'ooc', 'm-looc': 'ooc', 'm-dead': 'dead',
            'm-deadtag': 'dead', 'm-lobby': 'ooc', 'm-pm': 'pm', 'm-emote': 'ic', 'm-whisper': 'ic',
            'm-warn': 'warning', 'm-examine': 'other', 'm-plain': 'other', 'm-bogus': 'other' };
        for (const id in expected) check(typeOf(id) === expected[id], id + ' typed ' + expected[id] + ' [' + typeOf(id) + ']');
        check(Object.keys(expected).every(shown), 'All tab shows every message');
        check(tabs().join(',') === 'All,IC,Radio,OOC,Dead', 'Admin tab still hidden without admin output');

        tabButton('IC').click(); tabButton('OOC').click(); await delay(20);
        check(shown('m-ooc') && shown('m-looc') && shown('m-lobby') && shown('m-pm'), 'OOC tab shows OOC, LOOC, lobby and PMs');
        check(!shown('m-say') && !shown('m-dead') && !shown('m-plain') && !shown('m-radio'), 'OOC tab hides other types');
        add('m-say2', "<span class='chattype-ic'><span class='name'>Ann</span> says, \"yo\"</span>");
        await delay(20);
        const icBadge = tabButton('IC').querySelector('.unread');
        check(icBadge && icBadge.textContent === '1', 'IC tab counts unread speech');
        check(!shown('m-say2'), 'new IC line hidden on OOC tab');
        tabButton('IC').click(); await delay(20);
        check(shown('m-say') && shown('m-say2') && shown('m-radio') && shown('m-emote') && !shown('m-ooc'), 'IC tab shows speech, emotes and radio');
        check(!tabButton('IC').querySelector('.unread'), 'opening a tab clears its unread count');

        add('m-admin', "<span class=\"log_message\"><span class=\"prefix\">ADMIN LOG:</span> x</span>");
        await delay(20);
        check(tabs().indexOf('Admin') !== -1 && typeOf('m-admin') === 'admin', 'Admin tab appears after admin output');

        // Custom tab via settings, saved to storage.
        document.getElementById('chat-tab-settings').click(); await delay(20);
        check(document.getElementById('chat-settings').classList.contains('open'), 'settings panel opens');
        document.getElementById('chat-tab-add').click(); await delay(20);
        const boxes = document.querySelectorAll('.tab-config');
        const last = boxes[boxes.length - 1];
        const nameInput = last.querySelector('input[type="text"]');
        nameInput.value = 'Ghosts'; nameInput.dispatchEvent(new Event('input'));
        const checks = last.querySelectorAll('input[type="checkbox"]');
        checks[0].click(); checks[3].click(); // drop IC, add Dead
        await delay(20);
        const saved = JSON.parse(localStorage.getItem('civ13-chat-tabs-v1') || '[]');
        const ghosts = saved.find(t => t.name === 'Ghosts');
        check(ghosts && ghosts.types.join(',') === 'dead', 'custom tab saved [' + JSON.stringify(ghosts) + ']');
        window.__shot && await window.__shot();
        document.getElementById('chat-settings-close').click();
        tabButton('Ghosts').click(); await delay(20);
        check(shown('m-dead') && shown('m-deadtag') && !shown('m-say') && !shown('m-ooc'), 'custom tab filters to its types');

        // Per-type history: a flood of game messages keeps quiet dead chat.
        tabButton('All').click();
        for (let i = 0; i < 300; i++) add('flood-' + i, 'Flood line ' + i);
        await delay(60);
        check(document.getElementById('m-dead') && !document.getElementById('flood-0'), 'per-type trim keeps dead chat');
        check(document.querySelectorAll('.message[data-chat-type="other"]').length === 250, 'other type capped at 250');

        // Malformed saved settings fall back to defaults on the next load.
        localStorage.setItem('civ13-chat-tabs-v1', '{not json');
        check(typeof loadTabs === 'function' && loadTabs().map(t => t.name).join(',') === 'All,IC,Radio,OOC,Dead,Admin', 'malformed settings fall back to defaults');
        localStorage.removeItem('civ13-chat-tabs-v1');
    } catch (e) { failures.push('exception: ' + String(e && e.stack || e)); }
    document.documentElement.setAttribute('data-chat-test', failures.length ? 'FAIL: ' + failures.join(' | ') : 'PASS');
})();`;
if (html.split('</body>').length !== 2) throw new Error('Body anchor changed');
html = html.replace('</body>', '<script>' + script + '</script></body>');
const dir = fs.mkdtempSync(path.join(scratch, 'chat-filter-'));
const fixture = path.join(dir, 'fixture.html');
fs.writeFileSync(fixture, html);
for (const name of ['Alegreya-Regular.ttf', 'Alegreya-Bold.ttf', 'Alegreya-Italic.ttf', 'Alegreya-BoldItalic.ttf', 'Alegreya-Black.ttf', 'Wizard.ttf']) {
  fs.copyFileSync(path.join(root, 'interface/fonts', name), path.join(dir, name));
}
fs.copyFileSync(path.join(root, 'code/js/purify.min.js'), path.join(dir, 'purify.min.js'));

(async function () {
  let context, verdict = null, closeOk = false;
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
    if (process.env.CHAT_SCREENSHOT) {
      await page.exposeFunction('__shot', () => page.screenshot({ path: process.env.CHAT_SCREENSHOT }));
    }
    await page.goto(pathToFileURL(fixture).href, { waitUntil: 'load', timeout: 15000 });
    await page.waitForFunction(() => document.documentElement.hasAttribute('data-chat-test'), null, { timeout: 15000 });
    verdict = await page.getAttribute('html', 'data-chat-test');
    if (errors.length) throw new Error('Page errors: ' + errors.join(' | '));
    if (verdict !== 'PASS') throw new Error('Browser assertion: ' + (verdict || 'missing verdict'));
    console.log('PASS chat filter browser cases; evidence: ' + dir);
  } catch (err) {
    console.error(String(err) + '; evidence: ' + dir);
    process.exitCode = 1;
  } finally {
    if (context) {
      try { await context.close(); closeOk = true; } catch (err) { console.error('Browser cleanup failed: ' + err); process.exitCode = 1; }
    }
    fs.writeFileSync(path.join(dir, 'browser.cleanup.json'), JSON.stringify({ contextClosed: closeOk, verdict, errors }));
  }
})().catch(err => { console.error(err); process.exitCode = 1; });
