// Headless Chromium layout test of the actual chat page; no server or BYOND.
// Set CHROME_BIN to an installed Chrome/Chromium and CHAT_TEST_TMP to a scratch
// directory. CHAT_NEGATIVE_CONTROL=1 runs the frozen original page.
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
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
const negative = process.env.CHAT_NEGATIVE_CONTROL === '1';
const htmlPath = negative ? path.join(__dirname, 'fixtures/chat-before-tail-follow.html') : path.join(root, 'interface/chat/chat.html');
const fontData = fs.readFileSync(path.resolve(__dirname, '../../interface/fonts/Alegreya-Regular.ttf')).toString('base64');
const pageBytes = fs.readFileSync(htmlPath);
if (negative && crypto.createHash('sha256').update(pageBytes.toString('utf8').replace(/\r\n/g, '\n'), 'utf8').digest('hex') !== '6b3a01d2d0e69d7d0b44e1c06c1342029e5f6c8a3baa7971cc30bd66677964d4') {
  throw new Error('Original-page fixture does not match the reviewed preimage');
}
let html = pageBytes.toString('utf8');
const bridge = "window.location.href = 'byond://?chat_ready=1';";
if (html.split(bridge).length !== 2) throw new Error('Chat ready bridge anchor changed');
html = html.replace(bridge, 'window.__chatTestReady = true;');
if (process.env.CHAT_NO_RESIZE_OBSERVER === '1') {
  html = html.replace('<script src="purify.min.js"></script>', '<script>window.ResizeObserver = undefined; window.__noResizeObserver = true;</script><script src="purify.min.js"></script>');
}
const script = String.raw`
(async function () {
    const failures = [];
    const c = document.getElementById('chat-container');
    const messages = document.getElementById('messages');
    const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
    const tail = () => c.scrollHeight - c.clientHeight - c.scrollTop <= 2;
    const check = (ok, label) => { if (!ok) failures.push(label); };
    const move = value => { c.scrollTop = value; c.dispatchEvent(new Event('scroll')); };
    const add = text => window.receiveMessage(text, true);
    try {
        check(window.__chatTestReady, 'chat initialization');
        window.receiveMessage(encodeURIComponent('<span id="safe-probe">safe</span><img id="sanitize-probe" src="data:image/svg+xml,%3Csvg%20xmlns=%22http://www.w3.org/2000/svg%22/%3E" onerror="window.__unsafe=1">'));
        await delay(50);
        const sanitized = document.getElementById('sanitize-probe');
        check(window.DOMPurify && sanitized && !sanitized.hasAttribute('onerror') && !window.__unsafe, 'normal chat sanitizer preserved');
        for (let i = 0; i < 35; i++) add('Initial line ' + i + ' with enough content to fill the chat.');
        await delay(120);
        check(c.scrollHeight > c.clientHeight && tail(), 'initial messages follow tail');
        add('Examine: ' + 'A wrapped description with several words. '.repeat(24));
        await delay(120);
        const last = messages.lastElementChild.getBoundingClientRect();
        const viewport = c.getBoundingClientRect();
        check(tail() && last.bottom <= viewport.bottom + 1, 'wrapped examine final line visible');

        move(25); await delay(50); const saved = c.scrollTop;
        add('New output while reading earlier lines'); await delay(120);
        check(saved > 0 && Math.abs(c.scrollTop - saved) < 1, 'scrolled-up position preserved on append');
        move(c.scrollHeight); await delay(80);
        check(tail(), 'return to bottom');

        add('Image incoming <img id="late-image" style="display:block;width:32px">');
        await delay(100); const beforeImage = c.scrollHeight;
        const img = document.getElementById('late-image');
        const loaded = new Promise((resolve, reject) => { img.onload = resolve; img.onerror = reject; });
        img.src = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="200"><rect width="32" height="200" fill="red"/></svg>');
        await loaded; await delay(160);
        check(c.scrollHeight > beforeImage + 100 && tail(), 'late image growth follows tail');

        add('Another image <img id="paused-image" style="display:block;width:32px">');
        await delay(80); move(35); await delay(50); const paused = c.scrollTop;
        const img2 = document.getElementById('paused-image');
        const loaded2 = new Promise((resolve, reject) => { img2.onload = resolve; img2.onerror = reject; });
        img2.src = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="240"><rect width="32" height="240" fill="blue"/></svg>');
        await loaded2; await delay(160);
        check(Math.abs(c.scrollTop - paused) < 1, 'scrolled-up position preserved on late image');

        move(c.scrollHeight); await delay(80);
        add('Responsive text ' + 'many words and descriptions '.repeat(25)); await delay(80);
        const beforeWrap = c.scrollHeight; c.style.width = '220px';
        if (window.__noResizeObserver) window.dispatchEvent(new Event('resize'));
        await delay(180);
        check(c.scrollHeight > beforeWrap && tail(), 'width reflow follows tail [before=' + beforeWrap + ', after=' + c.scrollHeight + ', top=' + c.scrollTop + ', client=' + c.clientHeight + ', follow=' + (typeof followingTail === 'undefined' ? 'missing' : followingTail) + ']');
        const message = messages.lastElementChild; const beforeFont = c.scrollHeight;
        message.style.fontSize = '28px';
        if (window.__noResizeObserver) document.fonts.dispatchEvent(new Event('loadingdone'));
        await delay(180);
        check(c.scrollHeight > beforeFont && tail(), 'font metric reflow follows tail [before=' + beforeFont + ', after=' + c.scrollHeight + ', top=' + c.scrollTop + ', client=' + c.clientHeight + ', follow=' + (typeof followingTail === 'undefined' ? 'missing' : followingTail) + ']');

        add('<span id="font-sample" style="font-family: ChatLateFont, monospace; font-size:26px">' + 'Wide words in a long readable description. '.repeat(35) + '</span>');
        await delay(100); const beforeLoadedFont = c.scrollHeight;
        const lateFont = new FontFace('ChatLateFont', 'url(data:font/ttf;base64,${fontData})');
        await lateFont.load(); document.fonts.add(lateFont);
        if (window.__noResizeObserver) document.fonts.dispatchEvent(new Event('loadingdone'));
        await delay(200);
        check(c.scrollHeight !== beforeLoadedFont && tail(), 'late font load reflow follows tail [before=' + beforeLoadedFont + ', after=' + c.scrollHeight + ']');

        move(40); await delay(80);
        c.style.width = '260px';
        if (window.__noResizeObserver) window.dispatchEvent(new Event('resize'));
        await delay(180);
        check(!tail(), 'scrolled-up reader is not moved to tail on reflow');
        move(c.scrollHeight); await delay(80);
        const beforeWheel = c.scrollTop;
        c.dispatchEvent(new WheelEvent('wheel', { deltaY: -100 }));
        add('Output arriving after upward wheel intent'); await delay(100);
        check(Math.abs(c.scrollTop - beforeWheel) < 1 && !tail(), 'upward wheel intent blocks pending follow');
        move(c.scrollHeight); await delay(80);
        check(tail(), 'return to tail after upward wheel');

        for (let i = 0; i < 260; i++) add('Trim message ' + i);
        await delay(160);
        check(messages.children.length === 250 && tail(), 'trim then follow tail');
        move(180); await delay(80);
        const topEdge = c.getBoundingClientRect().top;
        const anchor = Array.from(messages.children).find(node => node.getBoundingClientRect().bottom > topEdge);
        const anchorY = anchor && anchor.getBoundingClientRect().top;
        add('New output while old messages are trimmed'); await delay(120);
        check(anchor && anchor.isConnected && Math.abs(anchor.getBoundingClientRect().top - anchorY) < 1 && !tail(),
              'trim preserves anchor [connected=' + !!(anchor && anchor.isConnected) + ', delta=' + (anchor ? anchor.getBoundingClientRect().top - anchorY : 'none') + ', top=' + c.scrollTop + ', tail=' + tail() + ']');
        move(30); await delay(50); window.clearChat();
        for (let i = 0; i < 35; i++) add('Fresh chat after clear ' + i);
        await delay(120);
        check(messages.children.length === 35 && tail(), 'clear resets follow');
    } catch (e) { failures.push('exception: ' + String(e && e.stack || e)); }
    document.documentElement.setAttribute('data-chat-test', failures.length ? 'FAIL: ' + failures.join(' | ') : 'PASS');
})();`;
if (html.split('</body>').length !== 2) throw new Error('Body anchor changed');
html = html.replace('</body>', '<script>' + script + '</script></body>');
fs.mkdirSync(scratch, { recursive: true });
const dir = fs.mkdtempSync(path.join(scratch, 'chat-scroll-'));
const fixture = path.join(dir, 'fixture.html');
const profile = path.join(dir, 'profile');
fs.writeFileSync(fixture, html);
for (const name of ['Alegreya-Regular.ttf', 'Alegreya-Bold.ttf', 'Alegreya-Italic.ttf', 'Alegreya-BoldItalic.ttf', 'Alegreya-Black.ttf', 'Wizard.ttf']) {
  fs.copyFileSync(path.join(root, 'interface/fonts', name), path.join(dir, name));
}
fs.copyFileSync(path.join(root, 'code/js/purify.min.js'), path.join(dir, 'purify.min.js'));

// Use the same integrity-locked playwright-core and runner browser as TGUI.
// No BYOND bridge, server, browser download, or remote network is used.
(async function () {
  let context, verdict = null, closeOk = false;
  const errors = [];
  try {
    context = await chromium.launchPersistentContext(profile, {
      executablePath: chrome, headless: true, viewport: { width: 1000, height: 520 },
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
    await page.waitForFunction(() => document.documentElement.hasAttribute('data-chat-test'), null, { timeout: 15000 });
    verdict = await page.getAttribute('html', 'data-chat-test');
    fs.writeFileSync(path.join(dir, 'browser.stdout.html'), await page.content());
    if (errors.length) throw new Error('Page errors: ' + errors.join(' | '));
    if (negative) {
      const expected = ['scrolled-up position preserved on append', 'late image growth follows tail',
        'width reflow follows tail', 'upward wheel intent blocks pending follow', 'trim preserves anchor'];
      if (!verdict || !verdict.startsWith('FAIL: ') || verdict.includes('exception:') || expected.some(label => !verdict.includes(label))) {
        throw new Error('Original-page control did not fail the expected assertions: ' + verdict);
      }
      console.log('PASS original-page negative control; evidence: ' + dir);
    } else {
      if (verdict !== 'PASS') throw new Error('Browser assertion: ' + (verdict || 'missing verdict'));
      console.log('PASS chat scroll browser cases; evidence: ' + dir);
    }
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
