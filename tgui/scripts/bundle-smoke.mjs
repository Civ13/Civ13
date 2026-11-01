// Executes the production bundle with real tgui-core/React in an isolated DOM.
// This verifies application wiring, not layout pixels or native BYOND behavior.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { JSDOM, VirtualConsole } from 'jsdom';
import vm from 'node:vm';
// Compile the actual retained template; this is an offline fallback fixture.
const religionClassicContext = vm.createContext({ module: { exports: {} } });
vm.runInContext('Object.size = value => Object.keys(value).length;', religionClassicContext);
vm.runInContext(readFileSync(new URL('../../UI/js/libraries/doT.js', import.meta.url), 'utf8'), religionClassicContext);
const renderReligionClassic = religionClassicContext.module.exports.template(readFileSync(new URL('../../UI/templates/religion_list.tmpl', import.meta.url), 'utf8'));
const religionClassicMarkup = renderReligionClassic({ religions: [
  { name: 'First', points: 0 }, { name: 'Second', points: -2 }, { name: 'Third', points: 12.5 },
  { name: '&lt;script&gt;fictional&lt;/script&gt;', points: '<img src=x>' },
] }, {}, {});
assert.ok(religionClassicMarkup.indexOf('First') < religionClassicMarkup.indexOf('Second'));
assert.ok(religionClassicMarkup.includes('>0</td>'));
assert.ok(religionClassicMarkup.includes('>-2</td>'));
assert.ok(religionClassicMarkup.includes('>12.5</td>'));
assert.ok(religionClassicMarkup.includes('&lt;script&gt;fictional&lt;/script&gt;'));
assert.ok(!religionClassicMarkup.includes('<script>'));
assert.ok(!religionClassicMarkup.includes('<img'));
assert.ok(renderReligionClassic({ religions: [] }, {}, {}).includes('No religions have been founded.'));
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
  await update('religion_list.tmpl', { religions: [
    { name: 'Fictional zero', points: 0 }, { name: 'Fictional fractional', points: 12.5 },
    { name: '&lt;script&gt;inert&lt;/script&gt;', points: -2 },
  ] }, 1);
  assert.equal(w.document.querySelectorAll('table[aria-label="Religion list"] tbody tr').length, 3);
  assert.ok(w.document.body.textContent.includes('Fictional zero'));
  assert.ok(w.document.body.textContent.includes('12.5'));
  assert.ok(w.document.body.textContent.includes('<script>inert</script>'));
  assert.equal(w.document.querySelectorAll('script:not([src])').length, 0);
  assert.equal(w.document.querySelectorAll('table button,table a').length, 0);
  click('Classic interface'); assert.equal(messages.at(-1).type, 'fallback');
  assert.deepEqual(errors, []);
  process.stdout.write('PASS: real bootstrap and production bundle complete ready/snapshot/ack, reject stale generation, render ten routes plus Religion List, compile classic fallback, dispatch/block actions, escape data and invoke fallback\n');
} finally { w.close(); }
