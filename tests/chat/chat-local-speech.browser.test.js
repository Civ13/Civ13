// Exact chat page and receiveMessage, with a counted local/remote speech provider.
// No installed voice, network service or BYOND server is used.
'use strict';
const assert = require('assert/strict');
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const root = path.resolve(__dirname, '../..');
const chrome = process.env.CHROME_BIN || process.env.CHROMIUM_PATH;
const scratch = process.env.CHAT_TEST_TMP;
if (!chrome || !scratch) throw new Error('Set CHROMIUM_PATH and CHAT_TEST_TMP');
fs.mkdirSync(scratch, { recursive: true });
process.env.TMPDIR = scratch;
const modulePath = process.env.PLAYWRIGHT_CORE_PATH || path.join(root, 'tgui/node_modules/playwright-core');
const lock = JSON.parse(fs.readFileSync(path.join(root, 'tgui/package-lock.json'), 'utf8'));
assert.equal(require(path.join(modulePath, 'package.json')).version, lock.packages['node_modules/playwright-core'].version);
const { chromium } = require(modulePath);
const dir = fs.mkdtempSync(path.join(scratch, 'chat-local-speech-'));
const file = path.join(dir, 'fixture.html');
const html = fs.readFileSync(path.join(root, 'interface/chat/chat.html'), 'utf8');
const bridge = "window.location.href = 'byond://?chat_ready=1';";
assert.equal(html.split(bridge).length, 2);
fs.writeFileSync(file, html.replace(bridge, 'window.__chatTestReady = true;'));
fs.copyFileSync(path.join(root, 'code/js/purify.min.js'), path.join(dir, 'purify.min.js'));
for (const filename of fs.readdirSync(path.join(root, 'interface/fonts'))) {
  if (filename.endsWith('.ttf')) fs.copyFileSync(path.join(root, 'interface/fonts', filename), path.join(dir, filename));
}
const tts = body => "<span class='chattype-ic'><span class='name'>Not spoken</span> says, <span class='chat-local-voice'><span class='chat-tr'>" + body + '</span></span></span>';
const send = (page, html) => page.evaluate(raw => window.receiveMessage(encodeURIComponent(raw)), html);
const speakLog = page => page.evaluate(() => window.calls);
const finish = page => page.evaluate(() => window.active.onend());
const status = page => page.locator('#chat-tts-status').textContent();
const openSettings = page => page.locator('#chat-tab-settings').click();

(async () => {
  const browser = await chromium.launch({ executablePath: chrome, args: ['--no-sandbox'] });
  try {
    const context = await browser.newContext();
    const external = [];
    await context.route('**/*', async route => {
      if (/^(file|data):/.test(route.request().url())) return route.continue();
      external.push(route.request().url());
      return route.abort();
    });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', err => errors.push(err.message));
    await page.addInitScript(() => {
      window.calls = [];
      window.cancels = 0;
      window.voices = [
        { name: 'Hosted Default', localService: false, lang: 'en-US', default: true },
        { name: 'Missing flag', lang: 'en-US' },
        { name: 'Local voice', localService: true, lang: 'en-US' },
      ];
      const synth = new EventTarget();
      synth.getVoices = () => window.voices;
      synth.speak = utterance => {
        window.active = utterance;
        window.calls.push([utterance.text, utterance.voice.name]);
      };
      synth.cancel = () => { window.cancels++; };
      Object.defineProperty(window, 'speechSynthesis', { value: synth, configurable: true });
      Object.defineProperty(window, 'SpeechSynthesisUtterance', {
        value: function (text) { this.text = text; },
        configurable: true,
      });
    });
    await page.goto(pathToFileURL(file).href);
    await page.evaluate(() => window.setChatIdentity('fixturelistener'));
    await send(page, tts('Off by default'));
    assert.deepEqual(await speakLog(page), []);

    await openSettings(page);
    await page.locator('#chat-tts-preview').click();
    assert.deepEqual(await speakLog(page), [['This is your local chat speech preview.', 'Local voice']]);
    assert.ok(!(await page.locator('#chat-tts-on').isChecked()), 'preview does not enable reading');
    await finish(page);
    assert.match(await status(page), /Local preview completed/);
    await page.evaluate(() => { window.calls.length = 0; });
    await page.locator('#chat-tts-on').check();
    await send(page, tts('Hello &amp; <b>friends</b>'));
    assert.deepEqual(await speakLog(page), [['Hello & friends', 'Local voice']]);
    await finish(page);

    await send(page, "<span class='chattype-ic'><span class='chat-notr'>Unheard</span>" + tts('Must not read') + '</span>');
    await send(page, "<span class='chattype-ic'><span class='chat-tr'>Translation only</span></span>");
    await send(page, tts('Not IC').replace('chattype-ic', 'chattype-radio'));
    await send(page, tts('Not OOC').replace('chattype-ic', 'chattype-ooc'));
    await send(page, "<span class='chattype-ic'>&lt;span class='chat-local-voice'&gt;Plain text&lt;/span&gt;</span>");
    assert.equal((await speakLog(page)).length, 1);

    await page.evaluate(() => {
      window.voices = window.voices.filter(v => v.localService !== true);
      speechSynthesis.dispatchEvent(new Event('voiceschanged'));
    });
    await send(page, tts('No hosted fallback'));
    assert.match(await status(page), /No on-device/);
    assert.ok(await page.locator('#chat-tts-preview').isDisabled());
    assert.equal((await speakLog(page)).length, 1);
    await page.evaluate(() => window.voices.push({ name: 'Local voice', localService: true, lang: 'en-US' }));

    await send(page, tts('A'.repeat(400)));
    assert.equal((await speakLog(page)).at(-1)[0].length, 300);
    for (let i = 0; i < 10; i++) await send(page, tts('Queue line ' + i));
    assert.equal((await speakLog(page)).length, 2);
    for (let i = 0; i < 4; i++) await finish(page);
    assert.deepEqual((await speakLog(page)).slice(2).map(line => line[0]), ['Queue line 0', 'Queue line 1', 'Queue line 2']);

    await send(page, tts('Cancel active'));
    await send(page, tts('Discard queued'));
    await page.locator('#chat-tts-on').uncheck();
    assert.equal(await page.evaluate(() => window.cancels), 1);
    await finish(page); // obsolete end callback after cancellation
    assert.equal((await speakLog(page)).at(-1)[0], 'Cancel active');

    await page.locator('#chat-tts-on').check();
    await send(page, tts('Not replayed'));
    await finish(page);
    await page.reload();
    await page.evaluate(() => window.setChatIdentity('fixturelistener'));
    await openSettings(page);
    assert.ok(await page.locator('#chat-tts-on').isChecked(), 'choice follows this browser, not the server');
    assert.match(await page.locator('#messages').textContent(), /Not replayed/);
    assert.deepEqual(await speakLog(page), []);
    await page.evaluate(() => window.selectChatTab(2)); // Radio
    await send(page, tts('Filtered IC'));
    assert.deepEqual(await speakLog(page), []);
    await page.evaluate(() => window.selectChatTab(0));
    await send(page, tts('Live after reload'));
    assert.deepEqual(await speakLog(page), [['Live after reload', 'Local voice']]);

    // Editing the active tab applies its filter without selecting another tab.
    await send(page, tts('Queued before editing'));
    const ic = page.locator('#chat-settings-list .tab-config').first()
      .getByRole('checkbox', { name: 'IC speech and emotes', exact: true });
    const previousCancels = await page.evaluate(() => window.cancels);
    await ic.uncheck();
    assert.equal(await page.evaluate(() => window.cancels), previousCancels + 1,
      'editing the active tab stops its current IC speech');
    await finish(page); // A stale native end event cannot revive the queue.
    await ic.check();
    await send(page, tts('Only new speech after editing'));
    assert.deepEqual((await speakLog(page)).map(line => line[0]),
      ['Live after reload', 'Only new speech after editing']);
    await finish(page);

    const legacy = await context.newPage();
    await legacy.addInitScript(() => {
      Object.defineProperty(window, 'SpeechSynthesisUtterance', { value: undefined, configurable: true });
    });
    await legacy.goto(pathToFileURL(file).href);
    assert.ok(await legacy.locator('#chat-tts-on').isDisabled());
    assert.ok(await legacy.locator('#chat-tts-preview').isDisabled());
    assert.match(await status(legacy), /does not support/);
    await send(legacy, tts('Still readable'));
    assert.match(await legacy.locator('#messages').textContent(), /Still readable/);
    assert.deepEqual(errors, []);
    assert.deepEqual(external, [], 'speech submits no network requests');
    console.log('PASS actual chat page: local voice only, opt in, scope, bounds, cancellation, history, legacy and no egress');
  } catch (e) {
    fs.writeFileSync(path.join(dir, 'browser.failure'), String(e.stack));
    throw e;
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
