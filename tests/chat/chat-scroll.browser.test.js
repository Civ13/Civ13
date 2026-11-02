// Headless Chromium layout test of the actual chat page; no server or BYOND.
// Set CHROME_BIN to an installed Chrome/Chromium and CHAT_TEST_TMP to a scratch
// directory. CHAT_HTML can point to a historical page for negative controls.
'use strict';
const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const { pathToFileURL } = require('url');
const chrome = process.env.CHROME_BIN;
const scratch = process.env.CHAT_TEST_TMP;
if (!chrome || !scratch) throw new Error('Set CHROME_BIN and CHAT_TEST_TMP');
const htmlPath = process.env.CHAT_HTML || path.resolve(__dirname, '../../interface/chat/chat.html');
const fontData = fs.readFileSync(path.resolve(__dirname, '../../interface/fonts/Alegreya-Regular.ttf')).toString('base64');
let html = fs.readFileSync(htmlPath, 'utf8');
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
const args = ['--headless=new', '--disable-gpu', '--disable-extensions', '--disable-background-networking',
  '--disable-sync', '--no-first-run', '--no-default-browser-check', '--host-resolver-rules=MAP * ~NOTFOUND',
  '--user-data-dir=' + profile, '--remote-debugging-pipe', '--no-startup-window'];

// The debugging pipe is an owned process pipe, not a listening TCP port. Run
// against real compositor frames: virtual time can starve ResizeObserver.
(async function () {
  const browser = cp.spawn(chrome, args, { windowsHide: true, stdio: ['ignore', 'ignore', 'pipe', 'pipe', 'pipe'] });
  let log = '';
  browser.stderr.on('data', chunk => { if (log.length < 100000) log += chunk.toString(); });
  let input = Buffer.alloc(0), next = 0;
  const pending = new Map();
  const exited = new Promise(resolve => browser.once('exit', (code, signal) => {
    for (const p of pending.values()) p.reject(new Error('Browser exited before reply'));
    pending.clear();
    resolve({ code, signal });
  }));
  browser.on('error', err => { for (const p of pending.values()) p.reject(err); pending.clear(); });
  browser.stdio[3].on('error', err => { for (const p of pending.values()) p.reject(err); pending.clear(); });
  browser.stdio[4].on('data', chunk => {
    input = Buffer.concat([input, chunk]);
    for (;;) {
      const end = input.indexOf(0);
      if (end < 0) break;
      const message = JSON.parse(input.subarray(0, end).toString('utf8'));
      input = input.subarray(end + 1);
      if (message.id && pending.has(message.id)) {
        const p = pending.get(message.id); pending.delete(message.id);
        if (message.error) p.reject(new Error(message.error.message)); else p.resolve(message.result);
      }
    }
  });
  function send(method, params, sessionId) {
    const id = ++next;
    return new Promise((resolve, reject) => {
      pending.set(id, { resolve, reject });
      browser.stdio[3].write(JSON.stringify({ id, method, params: params || {}, ...(sessionId ? { sessionId } : {}) }) + '\0');
    });
  }
  const timer = setTimeout(() => browser.kill(), 30000);
  try {
    const target = await send('Target.createTarget', { url: 'about:blank' });
    const attached = await send('Target.attachToTarget', { targetId: target.targetId, flatten: true });
    await send('Page.enable', {}, attached.sessionId);
    await send('Runtime.enable', {}, attached.sessionId);
    await send('Page.navigate', { url: pathToFileURL(fixture).href }, attached.sessionId);
    let verdict = null;
    for (let i = 0; i < 150; i++) {
      await new Promise(resolve => setTimeout(resolve, 100));
      const response = await send('Runtime.evaluate', { expression: "document.documentElement && document.documentElement.getAttribute('data-chat-test')", returnByValue: true }, attached.sessionId);
      verdict = response.result && response.result.value;
      if (verdict) break;
    }
    const page = await send('Runtime.evaluate', { expression: 'document.documentElement.outerHTML', returnByValue: true }, attached.sessionId);
    fs.writeFileSync(path.join(dir, 'browser.stdout.html'), page.result.value || '');
    if (verdict !== 'PASS') throw new Error('Browser assertion: ' + (verdict || 'missing verdict'));
    console.log('PASS chat scroll browser cases; evidence: ' + dir);
  } catch (err) {
    console.error(String(err) + '; evidence: ' + dir);
    process.exitCode = 1;
  } finally {
    clearTimeout(timer);
    try { browser.stdio[3].write(JSON.stringify({ id: ++next, method: 'Browser.close', params: {} }) + '\0'); } catch (_) {}
    let end = await Promise.race([exited, new Promise(resolve => setTimeout(() => resolve(null), 3000))]);
    if (!end) {
      browser.kill();
      end = await Promise.race([exited, new Promise(resolve => setTimeout(() => resolve(null), 3000))]);
    }
    fs.writeFileSync(path.join(dir, 'browser.stderr.log'), log);
    fs.writeFileSync(path.join(dir, 'browser.cleanup.json'), JSON.stringify({ ownedBrowserExited: !!end, end }));
    if (!end) { console.error('Owned browser process did not exit; evidence: ' + dir); process.exitCode = 1; }
  }
})().catch(err => { console.error(err); process.exitCode = 1; });
