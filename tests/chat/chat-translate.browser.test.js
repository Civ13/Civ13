// Headless Chromium test of on-device chat translation (docs/chat-translation.md).
// A fake Translator and LanguageDetector stand in for the browser's built-in
// ones; no server, BYOND or network. Set CHROME_BIN (or CHROMIUM_PATH) and
// CHAT_TEST_TMP. CHAT_SCREENSHOT=<path> saves a picture of translated chat.
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
const dir = fs.mkdtempSync(path.join(scratch, 'chat-translate-'));
const fixture = path.join(dir, 'fixture.html');
fs.writeFileSync(fixture, html);
for (const name of ['Alegreya-Regular.ttf', 'Alegreya-Bold.ttf', 'Alegreya-Italic.ttf', 'Alegreya-BoldItalic.ttf', 'Alegreya-Black.ttf', 'Wizard.ttf']) {
  fs.copyFileSync(path.join(root, 'interface/fonts', name), path.join(dir, name));
}
fs.copyFileSync(path.join(root, 'code/js/purify.min.js'), path.join(dir, 'purify.min.js'));

// Fake on-device APIs. Spanish and German are "detected" by keyword; es->en is
// installed, de->en must be downloaded first. Every call is recorded.
const fakeApis = `
  window.__tr = { detected: [], translated: [], created: [], availability: [] };
  const words = { es: ['hola', 'amigo', 'hierro', 'rio'], de: ['eisen', 'fluss', 'danke'] };
  const dict = { 'hola amigo': 'hello friend', 'vendo hierro en el rio': 'selling iron at the river', 'danke fur das eisen': 'thanks for the iron' };
  const ready = { 'es>en': 'available', 'de>en': 'downloadable', 'es>de': 'available', 'en>de': 'available' };
  window.LanguageDetector = {
    availability: async () => 'available',
    create: async () => ({ detect: async text => {
      window.__tr.detected.push(text);
      const lower = text.toLowerCase();
      for (const lang in words) if (words[lang].some(w => lower.includes(w))) return [{ detectedLanguage: lang, confidence: 0.95 }];
      if (/^[a-z ,.!?'"]+$/i.test(text)) return [{ detectedLanguage: 'en', confidence: 0.9 }];
      return [{ detectedLanguage: 'und', confidence: 0.2 }];
    } }),
  };
  window.Translator = {
    availability: async o => { const k = o.sourceLanguage + '>' + o.targetLanguage; window.__tr.availability.push(k); return ready[k] || 'unavailable'; },
    create: async o => {
      const k = o.sourceLanguage + '>' + o.targetLanguage;
      window.__tr.created.push(k);
      if (ready[k] === 'downloadable') { if (!navigator.userActivation || !navigator.userActivation.isActive) throw new Error('needs a click'); ready[k] = 'available'; }
      return { translate: async text => { window.__tr.translated.push(k + ':' + text); const out = dict[text.toLowerCase()]; return out ? out : '[' + o.targetLanguage + '] ' + text; } };
    },
  };
`;

const say = s => encodeURIComponent(s);
const failures = [];
const check = (ok, label) => { if (!ok) failures.push(label); };
const settle = page => page.waitForTimeout(150);

(async function () {
  let context;
  const errors = [];
  try {
    context = await chromium.launchPersistentContext(path.join(dir, 'profile'), {
      executablePath: chrome, headless: true, viewport: { width: 560, height: 460 }, timeout: 15000,
      args: ['--disable-background-networking', '--disable-extensions', '--disable-sync', '--host-resolver-rules=MAP * ~NOTFOUND'],
    });
    await context.route('**/*', route => {
      const protocol = new URL(route.request().url()).protocol;
      return protocol === 'file:' || protocol === 'data:' ? route.continue() : route.abort();
    });
    const page = context.pages()[0] || await context.newPage();
    page.on('pageerror', error => errors.push(error.message));
    await page.addInitScript(fakeApis);
    const load = async () => {
      await page.goto(pathToFileURL(fixture).href, { waitUntil: 'load', timeout: 15000 });
      await page.waitForFunction(() => window.__chatTestReady === true, null, { timeout: 15000 });
    };
    await load();
    await page.evaluate(() => localStorage.clear());
    await load();
    const translations = () => page.evaluate(() => Array.from(document.querySelectorAll('#messages > .message')).map(m => {
      const t = m.querySelector('.chat-translation');
      return { text: m.textContent, tr: t ? t.textContent : null, setup: !!m.querySelector('.chat-translate-setup') };
    }));

    // Defaults: on, English.
    check(await page.evaluate(() => document.getElementById('chat-translate-on').checked), 'translation is on by default');
    check(await page.evaluate(() => document.getElementById('chat-translate-lang').value) === 'en', 'default language is English');

    await page.evaluate(msgs => msgs.forEach(m => window.receiveMessage(m)), [
      say("<span class='ooc'><span class='ooc'>OOC: <EM>Lucia:</EM> <span class='message chat-tr'>hola amigo</span></span></span>"),
      say("<span class='say'><span class='name'>Ada</span> says, \"<span class='chat-tr'>Vendo hierro en el rio</span>\"</span>"),
      say("<span class='say'><span class='name'>Bo</span> says, \"<span class='chat-notr'>hola amigo hierro</span>\"</span>"),
      say("<span class='ooc'>OOC: <EM>Cy:</EM> <span class='message chat-tr'>the storm is coming</span></span>"),
      say("<span class='emote'><b>Lucia</b> dice hola a todos</span>"),
    ]);
    await settle(page);
    let lines = await translations();
    if (process.env.CHAT_DEBUG) console.log(JSON.stringify(lines, null, 1), JSON.stringify(await page.evaluate(() => window.__tr)));
    check(lines[0].tr === 'Translated from Spanish:hello friend', 'OOC Spanish body translated into English: ' + lines[0].tr);
    check(lines[1].tr === 'Translated from Spanish:selling iron at the river', 'understood Spanish speech translated');
    check(lines[2].tr === null && !lines[2].setup, 'garbled (chat-notr) speech is never translated');
    check(lines[3].tr === null, 'English line is left alone');
    check(lines[4].tr && lines[4].tr.indexOf('Translated from Spanish') === 0, 'unmarked emote translated whole');
    const sent = await page.evaluate(() => window.__tr.detected);
    check(sent.indexOf('hola amigo') !== -1 && !sent.some(s => s.indexOf('Lucia:') !== -1), 'only the marked body is sent to the translator, not the name');
    check(!sent.some(s => s.indexOf('hola amigo hierro') !== -1), 'garbled text never reaches the detector');
    check(lines[0].text.indexOf('hola amigo') !== -1, 'original text stays on screen');

    // A pair that needs a download offers a button and never downloads on arrival.
    await page.evaluate(m => window.receiveMessage(m), say("<span class='ooc'>OOC: <EM>Hans:</EM> <span class='message chat-tr'>Danke fur das Eisen</span></span>"));
    await settle(page);
    lines = await translations();
    check(lines[5].setup && lines[5].tr === null, 'a downloadable pair shows a download button');
    check((await page.evaluate(() => window.__tr.created)).indexOf('de>en') === -1, 'no download starts without a click');
    await page.evaluate(m => window.receiveMessage(m), say("<span class='ooc'>OOC: <EM>Hans:</EM> <span class='message chat-tr'>Eisen am Fluss</span></span>"));
    await settle(page);
    lines = await translations();
    check(!lines[6].setup, 'each pair is offered once');
    await page.click('.chat-translate-setup button');
    await settle(page);
    lines = await translations();
    check(lines[5].tr === 'Translated from German:thanks for the iron', 'clicking downloads and translates that line: ' + lines[5].tr);

    // History keeps originals only and is never translated on restore.
    await page.evaluate(() => { window.setChatIdentity('alice'); });
    await page.evaluate(m => window.receiveMessage(m), say("<span class='ooc'>OOC: <EM>Lucia:</EM> <span class='message chat-tr'>hola amigo</span></span>"));
    await settle(page);
    if (process.env.CHAT_SCREENSHOT) await page.screenshot({ path: process.env.CHAT_SCREENSHOT });
    const stored = await page.evaluate(() => { window.dispatchEvent(new Event('pagehide')); return localStorage.getItem('civ13-chat-history-v1:alice') || ''; });
    check(stored.indexOf('hola amigo') !== -1, 'history saved');
    check(stored.indexOf('chat-translation') === -1 && stored.indexOf('hello friend') === -1, 'translations are not saved in history');
    const before = (await page.evaluate(() => window.__tr.detected.length));
    await load();
    await page.evaluate(() => window.setChatIdentity('alice'));
    await settle(page);
    check((await page.evaluate(() => window.__tr.detected.length)) === 0, 'restored history is not sent for translation (was ' + before + ' before reload)');
    check((await page.evaluate(() => document.querySelectorAll('.chat-translation').length)) === 0, 'restored lines show no translation');

    // Turning it off stops new work; changing language drops queued results.
    await page.evaluate(() => { const on = document.getElementById('chat-translate-on'); on.checked = false; on.dispatchEvent(new Event('change')); });
    await page.evaluate(m => window.receiveMessage(m), say("<span class='ooc'>OOC: <EM>Lucia:</EM> <span class='message chat-tr'>hola amigo</span></span>"));
    await settle(page);
    check((await page.evaluate(() => window.__tr.detected.length)) === 0, 'off means nothing is translated');
    await page.evaluate(() => {
      const on = document.getElementById('chat-translate-on'); on.checked = true; on.dispatchEvent(new Event('change'));
      const sel = document.getElementById('chat-translate-lang'); sel.value = 'de'; sel.dispatchEvent(new Event('change'));
    });
    check(JSON.parse(await page.evaluate(() => localStorage.getItem('civ13-chat-translate-v1'))).lang === 'de', 'language choice saved on this computer');
    await page.evaluate(m => window.receiveMessage(m), say("<span class='ooc'>OOC: <EM>Cy:</EM> <span class='message chat-tr'>the storm is coming</span></span>"));
    await settle(page);
    const last = (await translations()).pop();
    check(last.tr === 'Translated from English:[de] the storm is coming', 'English reader text translated into German when German is chosen: ' + last.tr);

    // Server translation: when the server offers it, the page sends only the
    // marked body with the reader's language and shows the server's answer.
    // An empty answer moves straight on to the next line.
    await page.evaluate(() => {
      window.__sent = [];
      window.chatSendTranslate = (id, lang, text) => {
        window.__sent.push({ id, lang, text });
        setTimeout(() => window.receiveTranslation(id, lang === 'en' && /hola/.test(text) ? 'es' : lang, lang === 'en' && /hola/.test(text) ? 'hi friend (server)' : ''), 20);
      };
      window.setTranslateServer('1');
      const sel = document.getElementById('chat-translate-lang'); sel.value = 'en'; sel.dispatchEvent(new Event('change'));
    });
    check((await page.evaluate(() => document.getElementById('chat-translate-status').textContent)).indexOf('game server translates') !== -1, 'status says the server translates');
    const detectedBefore = await page.evaluate(() => window.__tr.detected.length);
    await page.evaluate(msgs => msgs.forEach(m => window.receiveMessage(m)), [
      say("<span class='ooc'>OOC: <EM>Cy:</EM> <span class='message chat-tr'>the rain is coming</span></span>"),
      say("<span class='ooc'>OOC: <EM>Lucia:</EM> <span class='message chat-tr'>hola mundo</span></span>"),
      say("<span class='say'><span class='name'>Bo</span> says, \"<span class='chat-notr'>hola hierro</span>\"</span>"),
    ]);
    await settle(page);
    await settle(page);
    const sentToServer = await page.evaluate(() => window.__sent);
    check(sentToServer.length === 2 && sentToServer[0].text === 'the rain is coming' && sentToServer[1].text === 'hola mundo' && sentToServer[1].lang === 'en', 'server gets marked bodies with the language: ' + JSON.stringify(sentToServer));
    check((await page.evaluate(() => window.__tr.detected.length)) === detectedBefore, 'on-device detector unused in server mode');
    lines = await translations();
    check(lines[lines.length - 2].tr === 'Translated from Spanish:hi friend (server)', 'server translation shown: ' + lines[lines.length - 2].tr);
    check(lines[lines.length - 3].tr === null && lines[lines.length - 1].tr === null, 'empty answers and garbled speech show nothing');
    await page.evaluate(() => window.setTranslateServer('0'));

    // Bursts are bounded.
    await page.evaluate(() => { for (let i = 0; i < 200; i++) window.receiveMessage(encodeURIComponent("<span class='ooc'>OOC: <EM>X:</EM> <span class='message chat-tr'>hola amigo " + i + '</span></span>')); });
    await page.waitForTimeout(600);
    const burst = await page.evaluate(() => window.__tr.detected.length);
    check(burst <= 25, 'a burst of 200 lines is capped (' + burst + ' detected)');
    check(errors.length === 0, 'no page errors: ' + errors.join('; '));
  } finally {
    if (context) await context.close();
  }
  if (failures.length) {
    console.error('FAIL\n- ' + failures.join('\n- '));
    process.exit(1);
  }
  console.log('chat translation: all checks passed');
})().catch(e => { console.error(e); process.exit(1); });
