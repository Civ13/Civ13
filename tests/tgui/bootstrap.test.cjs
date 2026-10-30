// Execute the actual ES5 bootstrap with an injected browser boundary, no BYOND.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../../UI/tgui/civ13-tgui-bootstrap.js'), 'utf8');
function boot(ua, missingPromise = false) {
  const nodes = [], messages = [], timers = [];
  const loading = { style: {} }, button = {};
  const window = {
    Promise: missingPromise ? undefined : Promise, Map, Set, Symbol,
    location: {}, cef_to_byond: x => messages.push(x),
    setTimeout: f => (timers.push(f), timers.length), clearTimeout() {},
  };
  const document = {
    body: { getAttribute: key => ({ 'data-ref': '[0x123]', 'data-window': 'main[0x456]', 'data-generation': '2' })[key] },
    getElementById: id => id === 'tgui-loading' ? loading : button,
    createElement: tag => ({ tag }), head: { appendChild: x => nodes.push(x) },
  };
  vm.runInNewContext(source, { window, document, navigator: { userAgent: ua }, JSON, Object, Array, Number, encodeURIComponent });
  return { window, nodes, messages, timers, button, loading };
}
for (const ua of ['Trident/7.0', 'Chrome/122.0', 'Firefox/130.0']) {
  const env = boot(ua);
  assert.equal(env.nodes.length, 0, 'unsupported browsers must not parse modern assets');
  assert.match(env.messages[0], /type=fallback/);
  env.button.onclick();
  assert.equal(env.messages.length, 1, 'fallback is idempotent');
}
assert.equal(boot('Chrome/123.0', true).nodes.length, 0);
const env = boot('Chrome/123.0');
assert.equal(env.nodes.length, 2);
assert.equal(env.nodes[1].src, 'civ13-tgui.js');
env.window.receiveUpdateData('{"data":{"n":1}}');
assert.equal(env.window.Civ13Tgui.queue.length, 1);
env.window.Civ13Tgui.ready();
env.window.Civ13Tgui.ready();
assert.equal(env.messages.length, 1, 'ready is idempotent');
assert.match(env.messages[0], /generation=2&type=ready/);
env.window.Civ13Tgui.send('act/amount', { amount: 5 });
const action = new URL(env.messages[1]);
assert.equal(action.searchParams.get('src'), '[0x123]');
assert.equal(action.searchParams.get('window_id'), 'main[0x456]');
assert.deepEqual(JSON.parse(action.searchParams.get('payload')), { amount: 5 });
env.window.Civ13Tgui.fallback();
env.window.Civ13Tgui.send('act/amount', { amount: 10 });
assert.equal(env.messages.length, 3, 'fallback stops stale actions');
for (const failure of ['script', 'css', 'timeout', 'error', 'rejection']) {
  const test = boot('Chrome/130.0');
  if (failure === 'script') test.nodes[1].onerror();
  if (failure === 'css') test.nodes[0].onerror();
  if (failure === 'timeout') test.timers[0]();
  if (failure === 'error') test.window.onerror();
  if (failure === 'rejection') test.window.onunhandledrejection();
  assert.match(test.messages[0], /type=fallback/);
}
console.log('bootstrap contract: passed (legacy gate, queue, ready, identity, failure fallback, stale actions)');
const overflow = boot('Chrome/130.0');
for (let i = 0; i < 33; i++) overflow.window.receiveUpdateData('{}');
assert.equal(overflow.window.Civ13Tgui.queue.length, 32);
assert.match(overflow.messages[0], /type=fallback/, 'early update queue is bounded');
