// Actual ES5 bootstrap with fake transport/clock. No browser, socket or BYOND.
const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm'), path = require('node:path');
const { test } = require('node:test');
const source = fs.readFileSync(process.env.TGUI_BOOTSTRAP_SOURCE || path.join(__dirname, '../../UI/tgui/civ13-tgui-bootstrap.js'), 'utf8');
const dm = fs.readFileSync(process.env.TGUI_DM_SOURCE || path.join(__dirname, '../../code/modules/nano/tgui.dm'), 'utf8');
const config = (generation = 2) => ({ ref: '[0x123]', window: 'main[0x456]', generation, template: 'chem_disp.tmpl', status: 2 });
function boot(ua = 'Chrome/130.0', options = {}) {
  const nodes = [], messages = [], timers = [], cancelled = new Set(), loading = { style: {} }, button = {};
  const window = { Promise: options.missingPromise ? undefined : Promise, Map, Set, Symbol, location: {},
    cef_to_byond: url => { messages.push(url); options.deliver?.(url); },
    setTimeout: (callback, delay) => (timers.push({ callback, delay }), timers.length), clearTimeout: id => cancelled.add(id) };
  const document = { body: { getAttribute: key => ({ 'data-ref': '[0x123]', 'data-window': 'main[0x456]', 'data-generation': String(options.generation || 2) })[key] },
    getElementById: id => id === 'tgui-loading' ? loading : button, createElement: tag => ({ tag }), head: { appendChild: x => nodes.push(x) } };
  vm.runInNewContext(source, { window, document, navigator: { userAgent: ua }, JSON, Object, Array, Number, String, encodeURIComponent });
  return { window, nodes, messages, timers, cancelled, button, loading, expire: () => { for (let i = 0; i < timers.length; i++) if (!cancelled.has(i + 1)) timers[i].callback(); } };
}
const types = env => env.messages.map(url => new URL(url).searchParams.get('type'));
test('legacy gate and idempotent fallback', () => {
  for (const ua of ['Trident/7.0', 'Chrome/122.0', 'Firefox/130.0']) { const e = boot(ua); assert.equal(e.nodes.length, 0); e.button.onclick(); assert.deepEqual(types(e), ['fallback']); }
  assert.equal(boot('Chrome/123.0', { missingPromise: true }).nodes.length, 0);
});
test('React mount keeps watchdog pending until a valid current snapshot', () => {
  const e = boot(), b = e.window.Civ13Tgui; b.ready(); b.ready();
  assert.equal(e.nodes[1].src, 'civ13-tgui.js'); assert.deepEqual(types(e), ['ready']);
  assert.equal(e.cancelled.size, 0, 'React mount must not clear the startup watchdog'); assert.notEqual(e.loading.style.display, 'none');
  assert.equal(b.acceptSnapshot(config()), true); assert.deepEqual(types(e), ['ready', 'ack']); assert.ok(e.cancelled.has(1)); assert.equal(e.loading.style.display, 'none');
  b.acceptSnapshot(config()); e.timers[0].callback(); assert.deepEqual(types(e), ['ready', 'ack'], 'queued stale timer is harmless');
  b.send('act/amount', { amount: 5 }); const action = new URL(e.messages.at(-1));
  assert.equal(action.searchParams.get('src'), '[0x123]'); assert.equal(action.searchParams.get('window_id'), 'main[0x456]'); assert.deepEqual(JSON.parse(action.searchParams.get('payload')), { amount: 5 });
});
test('missing first snapshot times out after ready and stops stale actions', () => {
  const e = boot(), b = e.window.Civ13Tgui; b.ready(); e.expire();
  assert.deepEqual(types(e), ['ready', 'fallback']); assert.equal(b.acceptSnapshot(config()), false); b.send('act/amount', { amount: 10 }); assert.deepEqual(types(e), ['ready', 'fallback']);
});
test('stale or malformed snapshot cannot finish startup; delayed current one can', () => {
  const e = boot(), b = e.window.Civ13Tgui; b.ready();
  for (const change of [{ generation: 1 }, { window: 'other' }, { ref: '[0x999]' }, { template: null }, { status: NaN }, { status: 1.5 }, { status: 3 }]) assert.equal(b.acceptSnapshot({ ...config(), ...change }), false);
  assert.equal(b.acceptSnapshot(null), false); assert.equal(e.cancelled.size, 0); assert.deepEqual(types(e), ['ready']);
  assert.equal(b.acceptSnapshot(config()), true); e.expire(); assert.deepEqual(types(e), ['ready', 'ack']);
});
test('early snapshot waits for React before acknowledgement', () => {
  const e = boot(), b = e.window.Civ13Tgui; assert.equal(b.acceptSnapshot(config()), true); assert.equal(e.cancelled.size, 0); assert.deepEqual(types(e), []); b.ready(); assert.deepEqual(types(e), ['ready', 'ack']);
});
test('asset/error/timeout fallback, bounded queue and throwing bridge', () => {
  for (const failure of ['script', 'css', 'timeout', 'error', 'rejection']) { const e = boot();
    if (failure === 'script') e.nodes[1].onerror(); if (failure === 'css') e.nodes[0].onerror(); if (failure === 'timeout') e.expire(); if (failure === 'error') e.window.onerror(); if (failure === 'rejection') e.window.onunhandledrejection(); assert.deepEqual(types(e), ['fallback']); }
  const q = boot(); for (let i = 0; i < 33; i++) q.window.receiveUpdateData('{}'); assert.equal(q.window.Civ13Tgui.queue.length, 32); assert.deepEqual(types(q), ['fallback']);
  const broken = boot('Chrome/130.0', { deliver: () => { throw Error('bridge unavailable'); } }); broken.window.Civ13Tgui.ready(); broken.expire(); broken.expire(); assert.deepEqual(types(broken), ['ready', 'fallback']);
});
// Server behavior is modeled, not DM execution. Execute production watchdog
// guard expressions against fake owners/generations so omission controls matter.
const watchdog = dm.split('spawn(', 2)[1]?.split('use_legacy_renderer()', 1)[0];
const delay = Number(watchdog?.match(/^(\d+)\)/)?.[1]) * 100;
const guards = [...(watchdog || '').matchAll(/if \((.+)\)/g)].map(m => m[1]);
const actionGuard = dm.match(/if \((status != STATUS_INTERACTIVE[^\n]+)\)/)?.[1];
const completeTransfer = dm.split('/datum/nanoui/tgui/proc/complete_user_transfer', 2)[1]?.split('/datum/nanoui/tgui/proc/use_legacy_renderer', 1)[0];
const transferGuards = [...(completeTransfer || '').matchAll(/if \((.+)\)/g)].map(m => m[1]);
function server(options = {}) {
  assert.equal(delay, 20000); assert.equal(guards.length, 2);
  const client = {}, owner = { client }; client.mob = owner;
  const s = { user: owner, render_generation: 1, legacy_renderer: false, frontend_ready: false, frontend_acknowledged: false, pending_transfer_client: null, src_object: {}, state: {}, status: 2, fallbacks: 0, callbacks: [], actions: [] };
  let env;
  const fallback = () => { if (!s.state || !s.src_object || !s.user?.client || s.status === -1 || s.legacy_renderer) return; s.legacy_renderer = true; s.fallbacks++; open(); };
  const receive = (url, caller) => {
    const p = new URL(url).searchParams;
    if (!s.state || s.legacy_renderer || caller !== s.user || !caller?.client || !s.src_object || s.status === -1 || p.get('window_id') !== 'main[0x456]' || p.get('generation') !== String(s.render_generation) || options.drop?.includes(p.get('type'))) return;
    if (p.get('type') === 'ready') { s.frontend_ready = true; if (!options.dropSnapshot) env.window.Civ13Tgui.acceptSnapshot(config(s.render_generation)); }
    if (p.get('type') === 'ack' && s.frontend_ready) s.frontend_acknowledged = true;
    if (p.get('type') === 'fallback') fallback();
    if (p.get('type')?.startsWith('act/')) {
      const blocked = vm.runInNewContext(actionGuard.replace('copytext(message_type, 1, 5)', 'message_type.slice(0, 4)'), { ...s, STATUS_INTERACTIVE: 2, message_type: p.get('type') });
      if (!blocked) s.actions.push({ type: p.get('type'), payload: JSON.parse(p.get('payload')) });
    }
  };
  function open() {
    s.render_generation++; s.frontend_ready = false; s.frontend_acknowledged = false; s.pending_transfer_client = null; if (s.legacy_renderer) return;
    const captured = { open_generation: s.render_generation, open_user: s.user, open_client: s.user.client };
    s.callbacks.push(() => { if (guards.some(expr => vm.runInNewContext(expr, { ...s, ...captured }))) return; fallback(); });
    const caller = s.user; env = boot('Chrome/130.0', { generation: s.render_generation, deliver: url => receive(url, caller) });
  }
  function completeHook(linked_user) {
    if (linked_user !== s.user) return; // Manager visits only current owner's UIs.
    assert.equal(transferGuards.length, 2);
    if (transferGuards.some(expr => vm.runInNewContext(expr, { ...s, linked_user }))) return;
    s.pending_transfer_client = null; open();
  }
  open(); return { state: s, get env() { return env; }, receive, open,
    timeout: () => { for (const callback of [...s.callbacks]) callback(); },
    close: () => { s.render_generation++; s.frontend_ready = false; s.frontend_acknowledged = false; s.pending_transfer_client = null; s.state = null; },
    transfer: () => {
      const expected = s.user.client || s.pending_transfer_client;
      s.user = { client: null }; s.render_generation++; s.frontend_ready = false; s.frontend_acknowledged = false;
      s.pending_transfer_client = s.legacy_renderer ? null : expected;
      return s.user;
    },
    linkClient: linked_user => {
      if (client.mob) client.mob.client = null;
      linked_user.client = client; client.mob = linked_user;
      completeHook(linked_user);
    }, completeHook };
}
test('server watchdog recovers undelivered ready and client fallback', () => {
  const s = server({ drop: ['ready', 'fallback'] }); s.env.window.Civ13Tgui.ready(); s.env.expire(); assert.equal(s.state.frontend_ready, false); s.timeout(); assert.equal(s.state.fallbacks, 1); assert.equal(s.state.legacy_renderer, true); const generation = s.state.render_generation; const target = s.transfer(); s.linkClient(target); assert.equal(s.state.render_generation, generation + 1, 'classic transfer invalidates old startup but does not reopen modern UI'); s.open(); s.timeout(); assert.equal(s.state.fallbacks, 1, 'classic fallback stays sticky');
});
test('server watchdog recovers lost snapshot or ack; normal ack cancels recovery', () => {
  for (const options of [{ dropSnapshot: true, drop: ['fallback'] }, { drop: ['ack'] }]) { const s = server(options); s.env.window.Civ13Tgui.ready(); s.env.expire(); s.timeout(); assert.equal(s.state.fallbacks, 1); }
  const normal = server(); normal.env.window.Civ13Tgui.ready(); normal.timeout(); assert.equal(normal.state.frontend_acknowledged, true); assert.equal(normal.state.fallbacks, 0);
});
test('dropped ack rejects action; later valid ack admits only a fresh action once', () => {
  const drop = ['ack'], s = server({ drop }); s.env.window.Civ13Tgui.ready();
  assert.equal(s.state.frontend_ready, true); assert.equal(s.state.frontend_acknowledged, false);
  s.env.window.Civ13Tgui.send('act/amount', { amount: 10 });
  assert.equal(s.state.actions.length, 0, 'pending startup must reject action');
  drop.length = 0;
  const ack = s.env.messages.find(url => new URL(url).searchParams.get('type') === 'ack');
  s.receive(ack, s.state.user); assert.equal(s.state.frontend_acknowledged, true);
  assert.equal(s.state.actions.length, 0, 'ack must not replay the rejected action');
  s.env.window.Civ13Tgui.send('act/amount', { amount: 20 });
  assert.deepEqual(s.state.actions, [{ type: 'act/amount', payload: { amount: 20 } }]);
  s.timeout(); assert.equal(s.state.fallbacks, 0);
  const normal = server(); normal.env.window.Civ13Tgui.ready(); normal.env.window.Civ13Tgui.send('act/amount', { amount: 5 }); assert.equal(normal.state.actions.length, 1);
});
test('server callbacks cannot reopen closed/logged-out/deleted windows', () => {
  for (const change of [s => s.close(), s => { s.state.user.client = null; }, s => { s.state.src_object = null; }, s => { s.state.state = null; }, s => { s.state.status = -1; }]) { const s = server(); change(s); s.timeout(); assert.equal(s.state.fallbacks, 0); }
});
test('real pre-client transfer order invalidates immediately, then reopens after link', () => {
  const s = server(), oldEnv = s.env, oldCallback = s.state.callbacks[0], oldOwner = s.state.user; oldEnv.window.Civ13Tgui.ready();
  const target = s.transfer(); assert.equal(target.client, null); assert.equal(s.state.render_generation, 3); assert.equal(s.state.frontend_ready, false); assert.equal(s.state.frontend_acknowledged, false); assert.equal(s.env, oldEnv);
  oldEnv.window.Civ13Tgui.send('act/amount', { amount: 10 }); oldCallback(); assert.equal(s.state.actions.length, 0); assert.equal(s.state.fallbacks, 0);
  s.linkClient(target); assert.equal(s.state.render_generation, 4); assert.notEqual(s.env, oldEnv);
  assert.equal(s.env.window.Civ13Tgui.acceptSnapshot(config(2)), false);
  s.receive('byond://?window_id=main%5B0x456%5D&generation=4&type=ack', oldOwner); assert.equal(s.state.frontend_acknowledged, false);
  s.env.window.Civ13Tgui.ready(); s.timeout(); assert.equal(s.state.frontend_acknowledged, true); assert.equal(s.state.fallbacks, 0);
});
test('logout before post-client hook cannot reopen a closed transferred UI', () => {
  const s = server(), target = s.transfer(), oldEnv = s.env; s.close(); s.linkClient(target); s.timeout();
  assert.equal(s.env, oldEnv); assert.equal(s.state.state, null); assert.equal(s.state.pending_transfer_client, null); assert.equal(s.state.fallbacks, 0);
});
test('second pre-client transfer keeps intended client and rejects first completion', () => {
  const s = server(), first = s.transfer(), oldEnv = s.env, pending = s.state.pending_transfer_client;
  const second = s.transfer(); assert.equal(first.client, null); assert.equal(second.client, null); assert.equal(s.state.pending_transfer_client, pending);
  s.linkClient(first); assert.equal(s.env, oldEnv); assert.equal(s.state.user, second); assert.equal(s.state.render_generation, 4);
  s.linkClient(second); assert.equal(s.state.render_generation, 5); assert.notEqual(s.env, oldEnv);
  s.env.window.Civ13Tgui.ready(); s.timeout(); assert.equal(s.state.frontend_acknowledged, true); assert.equal(s.state.fallbacks, 0);
});
test('post-client completion requires reciprocal binding to the intended client', () => {
  const s = server(), target = s.transfer(), oldEnv = s.env;
  target.client = s.state.pending_transfer_client; // Stale one-way field; client still owns the old mob.
  s.completeHook(target); assert.equal(s.env, oldEnv, 'unlinked client must not reopen transferred UI');
  target.client = { mob: target }; s.completeHook(target); assert.equal(s.env, oldEnv, 'wrong client must not reopen transferred UI');
  target.client = null; s.linkClient(target); assert.notEqual(s.env, oldEnv);
});
test('same-owner reopen expires old generation; owner/client replacement expires callbacks', () => {
  const reopened = server(), oldCallback = reopened.state.callbacks[0]; reopened.open(); oldCallback();
  assert.equal(reopened.state.fallbacks, 0, 'old generation must not recover a new opening');
  reopened.env.window.Civ13Tgui.ready(); reopened.timeout(); assert.equal(reopened.state.fallbacks, 0);
  for (const replace of [s => { s.state.user = { client: s.state.user.client }; }, s => { s.state.user.client = {}; }]) {
    const s = server(); replace(s); s.timeout(); assert.equal(s.state.fallbacks, 0, 'old owner/client callback must expire');
  }
});
