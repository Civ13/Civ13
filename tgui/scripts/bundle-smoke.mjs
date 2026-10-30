// Executes the production bundle with real tgui-core/React in an isolated DOM.
// This verifies application wiring, not layout pixels or native BYOND behavior.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { JSDOM, VirtualConsole } from 'jsdom';
const errors = [];
const console = new VirtualConsole(); console.on('jsdomError', error => errors.push(error.message));
const dom = new JSDOM('<!doctype html><div id="root"></div>', { runScripts: 'outside-only', url: 'http://127.0.0.1/', virtualConsole: console });
const w = dom.window, messages = [];
let ready = false, fallback = false;
w.Civ13Tgui = { queue: [], send: (type, payload) => messages.push({ type, payload }), ready: () => { ready = true; }, fallback: () => { fallback = true; } };
const settle = () => new Promise(resolve => setTimeout(resolve, 40));
const update = async (template, data, status = 2) => { w.receiveUpdateData(JSON.stringify({ config: { template, title: 'Civ13', status }, data })); await settle(); };
const click = text => {
  const el = [...w.document.querySelectorAll('.Button,button')].find(el => el.textContent === text);
  assert.ok(el, `Missing control ${text}`);
  el.dispatchEvent(new w.MouseEvent('click', { bubbles: true }));
};
try {
  w.eval(readFileSync(new URL('../../UI/tgui/civ13-tgui.js', import.meta.url), 'utf8'));
  await settle(); assert.ok(ready);
  await update('chem_disp.tmpl', { amount: 5, chemicals: [{ title: 'Water', commands: { dispense: 'water' } }] });
  click('Water'); assert.equal(messages.at(-1).type, 'act/dispense'); assert.equal(messages.at(-1).payload.dispense, 'water');
  await update('chem_disp.tmpl', { amount: 5, chemicals: [{ title: 'Water', commands: { dispense: 'water' } }] }, 1);
  const before = messages.length; click('Water'); assert.equal(messages.length, before);
  for (const template of ['appearance_changer.tmpl', 'vending_machine.tmpl', 'vending_machine2.tmpl', 'vending_machine_gulag.tmpl', 'vending_machine_taotd.tmpl', 'warehouse_book.tmpl', 'faction_symbol.tmpl', 'faction_creation.tmpl', 'research_bench.tmpl']) {
    await update(template, {}); assert.equal(fallback, false, `Render failed: ${template}`);
  }
  await update('warehouse_book.tmpl', { items: [{ name: '&lt;img src=x onerror=alert(1)&gt;', amount: 1 }] });
  assert.ok(w.document.body.textContent.includes('<img src=x onerror=alert(1)>'));
  assert.equal(w.document.querySelectorAll('img').length, 0);
  click('Classic interface'); assert.ok(fallback);
  assert.deepEqual(errors, []);
  process.stdout.write('PASS: production React/tgui-core bundle renders all ten routes, dispatches actions, blocks read-only actions, escapes data and invokes fallback\n');
} finally { w.close(); }
