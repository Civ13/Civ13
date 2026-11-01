// Executes the production bundle with real tgui-core/React in an isolated DOM.
// This verifies application wiring, not layout pixels or native BYOND behavior.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { JSDOM, VirtualConsole } from 'jsdom';
import vm from 'node:vm';
const classic = vm.createContext({ module: { exports: {} } });
vm.runInContext('Object.size = value => Object.keys(value).length;', classic);
vm.runInContext(readFileSync(new URL('../../UI/js/libraries/doT.js', import.meta.url), 'utf8'), classic);
const renderFactionClassic = classic.module.exports.template(readFileSync(new URL('../../UI/templates/faction_list.tmpl', import.meta.url), 'utf8'));
const factionFixture = [
  { name: 'First', motto: 'Together &amp; safe', flavour: '&lt;script&gt;inert&lt;/script&gt;', members: 1, symbol: 'flist_first.png' },
  { name: 'Second', members: 2, symbol: '' },
  { name: '&lt;img src=x&gt;', members: 3, symbol: 'https://example.com/a.png' },
  { name: 'Unicode symbol', members: 4, symbol: 'flist_кириллица.png' },
];
const classicDom = new JSDOM(renderFactionClassic({ factions: factionFixture }, {}, {}));
assert.equal(classicDom.window.document.querySelectorAll('tbody tr').length, 4);
assert.equal(classicDom.window.document.querySelectorAll('img').length, 2);
assert.equal(classicDom.window.document.querySelectorAll('img')[0].getAttribute('src'), 'flist_first.png');
assert.equal(classicDom.window.document.querySelectorAll('img')[1].getAttribute('src'), encodeURIComponent('flist_кириллица.png'));
assert.equal(classicDom.window.document.querySelector('script'), null);
assert.ok(classicDom.window.document.body.textContent.includes('<script>inert</script>'));
assert.ok(classicDom.window.document.body.textContent.includes('1 member.'));
assert.ok(classicDom.window.document.body.textContent.includes('2 members.'));
assert.ok(classicDom.window.document.body.textContent.indexOf('First') < classicDom.window.document.body.textContent.indexOf('Second'));
assert.ok(renderFactionClassic({ factions: [] }, {}, {}).includes('No populated factions are available.'));
classicDom.window.close();
const errors = [];
const console = new VirtualConsole(); console.on('jsdomError', error => errors.push(error.message));
const dom = new JSDOM('<!doctype html><body data-ref="[0x123]" data-window="main[0x456]" data-generation="2"><div id="root"></div><p id="tgui-loading">Loading... <a id="tgui-legacy">Classic</a></p></body>', { runScripts: 'outside-only', url: 'http://127.0.0.1/', virtualConsole: console });
const w = dom.window, messages = [];
Object.defineProperty(w.navigator, 'userAgent', { value: 'Chrome/130.0 (JSDOM fixture)' });
w.cef_to_byond = url => {
  const params = new URL(url).searchParams;
  messages.push({ type: params.get('type'), payload: params.has('payload') ? JSON.parse(params.get('payload')) : undefined });
};
w.eval(readFileSync(new URL('../../UI/tgui/civ13-tgui-bootstrap.js', import.meta.url), 'utf8'));
const settle = () => new Promise(resolve => setTimeout(resolve, 40));
const update = async (template, data, status = 2) => { w.receiveUpdateData(JSON.stringify({ config: { template, title: 'Civ13', status, ref: '[0x123]', window: 'main[0x456]', generation: 2 }, data })); await settle(); };
const click = text => {
  const el = [...w.document.querySelectorAll('.Button,button')].find(el => el.textContent === text);
  assert.ok(el, `Missing control ${text}`);
  el.dispatchEvent(new w.MouseEvent('click', { bubbles: true }));
};
try {
  w.eval(readFileSync(new URL('../../UI/tgui/civ13-tgui.js', import.meta.url), 'utf8'));
  await settle(); assert.equal(messages[0]?.type, 'ready');
  assert.notEqual(w.document.getElementById('tgui-loading').style.display, 'none');
  await update('chem_disp.tmpl', { amount: 5, chemicals: [{ title: 'Water', commands: { dispense: 'water' } }] });
  assert.equal(messages[1]?.type, 'ack');
  assert.equal(w.document.getElementById('tgui-loading').style.display, 'none');
  w.receiveUpdateData(JSON.stringify({ config: { template: 'warehouse_book.tmpl', ref: '[0x123]', window: 'main[0x456]', generation: 1, status: 2 }, data: { items: [{ name: 'STALE GENERATION', amount: 99 }] } }));
  await settle(); assert.ok(!w.document.body.textContent.includes('STALE GENERATION'));
  click('Water'); assert.equal(messages.at(-1).type, 'act/dispense'); assert.equal(messages.at(-1).payload.dispense, 'water');
  await update('chem_disp.tmpl', { amount: 5, chemicals: [{ title: 'Water', commands: { dispense: 'water' } }] }, 1);
  const before = messages.length; click('Water'); assert.equal(messages.length, before);
  for (const template of ['appearance_changer.tmpl', 'vending_machine.tmpl', 'vending_machine2.tmpl', 'vending_machine_gulag.tmpl', 'vending_machine_taotd.tmpl', 'warehouse_book.tmpl', 'faction_symbol.tmpl', 'faction_creation.tmpl', 'research_bench.tmpl']) {
    await update(template, {}); assert.ok(!messages.some(message => message.type === 'fallback'), `Render failed: ${template}`);
  }
  await update('warehouse_book.tmpl', { items: [{ name: '&lt;img src=x onerror=alert(1)&gt;', amount: 1 }] });
  assert.ok(w.document.body.textContent.includes('<img src=x onerror=alert(1)>'));
  assert.equal(w.document.querySelectorAll('img').length, 0);
  await update('faction_list.tmpl', { factions: factionFixture }, 1);
  assert.equal(w.document.querySelectorAll('table[aria-label="Faction list"] tbody tr').length, 4);
  assert.equal(w.document.querySelectorAll('table img').length, 2);
  assert.ok(w.document.body.textContent.includes('Together & safe'));
  assert.ok(w.document.body.textContent.includes('<script>inert</script>'));
  assert.equal(w.document.querySelectorAll('table button,table a,table script').length, 0);
  await update('faction_list.tmpl', { factions: [] }, 1);
  assert.ok(w.document.body.textContent.includes('No populated factions are available.'));
  assert.equal(w.document.querySelectorAll('table img').length, 0);
  click('Classic interface'); assert.equal(messages.at(-1).type, 'fallback');
  assert.deepEqual(errors, []);
  process.stdout.write('PASS: real bootstrap and production bundle complete ready/snapshot/ack, reject stale generation, render ten routes plus Faction List and compile its classic fallback, dispatch/block actions, escape data and invoke fallback\n');
} finally { w.close(); }
