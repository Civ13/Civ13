// Offline tests for the Edge translator service: the language detector and the
// HTTP service with a stand-in for Edge. Run: node tools/edge-translator/test/test.js
'use strict';
const assert = require('assert');
const http = require('http');
const { detect } = require('../detect');
const { createService } = require('../edge_translator');

const cases = [
  ['hola amigo, vendo hierro junto al rio', 'es'], ['¿dónde está el barco?', 'es'],
  ['Bonjour, quelqu\'un a du pain ?', 'fr'], ['привет, где лодка?', 'ru'], ['привіт, де човен? Її', 'uk'],
  ['danke für das Eisen, wo ist der Fluss', 'de'], ['obrigado, não tenho pão', 'pt'], ['ciao, dove sono le barche', 'it'],
  ['dzień dobry, gdzie jest łódź', 'pl'], ['merhaba, tekne nerede değil', 'tr'], ['hej, tack för hjälpen', 'sv'],
  ['こんにちは', 'ja'], ['你好朋友', 'zh'], ['안녕하세요', 'ko'], ['γεια σου', 'el'], ['مرحبا', 'ar'], ['नमस्ते', 'hi'], ['สวัสดี', 'th'],
  ['xin chào, cảm ơn bạn', 'vi'], ['the storm is coming, get inside', 'en'], ['!!! 123', 'und'], ['', 'und'],
];
for (const [text, want] of cases) assert.strictEqual(detect(text), want, text);

function post(port, body) {
  return new Promise((resolve, reject) => {
    const data = typeof body === 'string' ? body : JSON.stringify(body);
    const req = http.request({ host: '127.0.0.1', port, path: '/translate', method: 'POST', headers: { 'Content-Type': 'application/json' } }, res => {
      let raw = ''; res.setEncoding('utf8'); res.on('data', c => { raw += c; });
      res.on('end', () => resolve({ status: res.statusCode, body: raw ? JSON.parse(raw) : null }));
    });
    req.on('error', reject); req.end(data);
  });
}

(async () => {
  const calls = [];
  let active = 0, maxActive = 0;
  const backend = { async translate(s, t, text) {
    calls.push(s + '>' + t + ':' + text); active++; maxActive = Math.max(maxActive, active);
    await new Promise(r => setTimeout(r, 20)); active--;
    if (text.includes('fail')) throw new Error('boom');
    if (text.includes('download')) return null;
    return text === 'hola amigo' ? 'hello friend' : '[' + t + '] ' + text;
  } };
  const server = createService(backend);
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;
  let r = await post(port, { text: 'hola amigo', target: 'en' });
  assert.deepStrictEqual(r, { status: 200, body: { source: 'es', translation: 'hello friend' } });
  r = await post(port, { text: 'the storm is coming', target: 'en' });
  assert.deepStrictEqual(r.body, { source: 'en', translation: '' });
  assert.strictEqual(calls.length, 1, 'same-language line never reaches Edge');
  r = await post(port, { text: 'the storm is coming', target: 'de' });
  assert.strictEqual(r.body.translation, '[de] the storm is coming');
  r = await post(port, { text: 'hola download', target: 'en' });
  assert.deepStrictEqual(r.body, { source: 'es', translation: '' }, 'pack still downloading: empty');
  r = await post(port, { text: 'hola fail', target: 'en' });
  assert.strictEqual(r.status, 500);
  assert.strictEqual((await post(port, { text: 'hola', target: 'xx' })).status, 400);
  assert.strictEqual((await post(port, 'nope')).status, 400);
  assert.strictEqual((await post(port, { text: 'x'.repeat(9000), target: 'en' })).status, 413);
  const burst = await Promise.all([1, 2, 3, 4, 5].map(i => post(port, { text: 'hola amigo ' + i, target: 'en' })));
  assert.ok(burst.every(b => b.status === 200) && maxActive === 1, 'one line at a time through Edge');
  const long = await post(port, { text: 'hola ' + 'a'.repeat(600), target: 'en' });
  assert.ok(calls[calls.length - 1].length <= 'es>en:'.length + 500, 'text capped at 500 characters');
  assert.strictEqual(long.status, 200);
  await new Promise(r => server.close(r));
  console.log('edge translator: all checks passed');
})().catch(e => { console.error(e); process.exit(1); });
