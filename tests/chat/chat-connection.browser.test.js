// Headless Chromium test of the chat connection watchdog on the actual chat
// page; no server or BYOND. The page's pings are captured instead of sent. Set CHROME_BIN (or CHROMIUM_PATH) and CHAT_TEST_TMP.
// CHAT_SCREENSHOT=<path> also saves a picture of the lost/restored notices.
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

const script = String.raw`
(async function () {
    const failures = [];
    const check = (ok, label) => { if (!ok) failures.push(label); };
    const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
    const lost = () => document.querySelectorAll('.connection-lost').length;
    const restored = () => document.querySelectorAll('.connection-restored').length;
    let pings = 0, answer = true;
    window.chatSendPing = function () { pings++; if (answer) setTimeout(window.chatPong, 5); };
    try {
        check(window.__chatTestReady, 'chat initialization');
        await delay(150);
        check(pings === 0, 'no pings before the server starts the watchdog [' + pings + ']');

        window.startChatHeartbeat(20, 120);
        await delay(400);
        check(pings > 5, 'pings every tick [' + pings + ']');
        check(lost() === 0, 'answered pings raise no warning');

        answer = false;
        await delay(300);
        check(lost() === 1, 'unanswered pings warn once [' + lost() + ']');
        const text = document.querySelector('.connection-lost');
        check(text && /Connection lost/.test(text.textContent), 'warning says connection lost');
        check(text && text.closest('.message').getAttribute('data-chat-type') === 'warning', 'warning typed as warning');
        const before = pings;
        await delay(200);
        check(pings > before, 'keeps pinging while lost');
        check(lost() === 1, 'no repeated warnings while still lost [' + lost() + ']');

        // The notice stays visible on a tab that hides warnings.
        const dead = Array.from(document.querySelectorAll('.chat-tab')).find(b => b.firstChild.nodeValue === 'Dead');
        dead.click(); await delay(20);
        check(getComputedStyle(text.closest('.message')).display !== 'none', 'notice shows on every tab');
        Array.from(document.querySelectorAll('.chat-tab')).find(b => b.firstChild.nodeValue === 'All').click();

        answer = true;
        await delay(100);
        check(restored() === 1, 'answer after loss reports restored [' + restored() + ']');
        check(lost() === 1, 'no new warning after recovery');

        // Any game message also counts as an answer.
        answer = false;
        await delay(300);
        check(lost() === 2, 'second loss warns again [' + lost() + ']');
        window.receiveMessage(encodeURIComponent('You pick up the axe.'));
        check(restored() === 2, 'a game message also reports restored [' + restored() + ']');
        window.__shot && await window.__shot();

        // Ticks further apart than the timeout (a throttled hidden window)
        // with every ping answered must not warn.
        answer = true;
        window.startChatHeartbeat(500, 120);
        const lostBefore = lost();
        await delay(1300);
        check(lost() === lostBefore, 'slow ticks with answers do not warn [' + lost() + ']');
    } catch (e) { failures.push('exception: ' + String(e && e.stack || e)); }
    document.documentElement.setAttribute('data-chat-test', failures.length ? 'FAIL: ' + failures.join(' | ') : 'PASS');
})();`;
if (html.split('</body>').length !== 2) throw new Error('Body anchor changed');
html = html.replace('</body>', '<script>' + script + '</script></body>');
const dir = fs.mkdtempSync(path.join(scratch, 'chat-connection-'));
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
    console.log('PASS chat connection browser cases; evidence: ' + dir);
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
