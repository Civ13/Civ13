// Executes the production bundle with real tgui-core/React in an isolated DOM.
// This verifies application wiring, not layout pixels or native BYOND behavior.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { JSDOM, VirtualConsole } from 'jsdom';
import vm from 'node:vm';
// Compile the actual classic template with the retained NanoUI doT compiler.
// Object.size is the existing utility seam; no browser or native transport here.
const classic = vm.createContext({ module: { exports: {} } });
vm.runInContext('Object.size = function (value) { return Object.keys(value).length; };', classic);
vm.runInContext(readFileSync(new URL('../../UI/js/libraries/doT.js', import.meta.url), 'utf8'), classic);
const renderClassicLanguages = classic.module.exports.template(readFileSync(new URL('../../UI/templates/known_languages.tmpl', import.meta.url), 'utf8'));
const classicMarkup = renderClassicLanguages({ current_default: 'Common', languages: [{ name: 'Common', prefix: ':c', description: '&lt;script&gt;fictional&lt;/script&gt;', is_default: 1 }] }, {}, {});
assert.ok(classicMarkup.includes('Common (:c)'));
assert.ok(classicMarkup.includes('&lt;script&gt;fictional&lt;/script&gt;'));
assert.ok(!classicMarkup.includes('<script>'));
assert.ok(renderClassicLanguages({ languages: [], current_default: '' }, {}, {}).includes('No known languages are available.'));
// Exercise the actual retained NanoUI compiler and this reader's fallback.
const shipClassicContext = vm.createContext({ module: { exports: {} } });
vm.runInContext('Object.size = value => Object.keys(value).length;', shipClassicContext);
vm.runInContext(readFileSync(new URL('../../UI/js/libraries/doT.js', import.meta.url), 'utf8'), shipClassicContext);
const renderShipClassic = shipClassicContext.module.exports.template(readFileSync(new URL('../../UI/templates/ship_stocks.tmpl', import.meta.url), 'utf8'));
const shipClassicMarkup = renderShipClassic({ stocks: [
  { label: 'Wood', amount: 0, unit: 'logs' }, { label: 'Water', amount: 12.5, unit: 'units' },
  { label: '<script>fictional</script>', amount: '<img src=x>', unit: '<b>units</b>' },
] }, {}, {});
assert.ok(shipClassicMarkup.includes('>0 logs<'));
assert.ok(shipClassicMarkup.includes('>12.5 units<'));
assert.ok(shipClassicMarkup.includes('&#60;script&#62;fictional'));
assert.ok(!shipClassicMarkup.includes('<script>'));
assert.ok(!shipClassicMarkup.includes('<img'));
assert.ok(!shipClassicMarkup.includes('<b>'));
assert.ok(renderShipClassic({ stocks: [] }, {}, {}).includes('No stock snapshot is available.'));
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
const crewClassicContext = vm.createContext({ module: { exports: {} } });
vm.runInContext('Object.size = value => Object.keys(value).length;', crewClassicContext);
vm.runInContext(readFileSync(new URL('../../UI/js/libraries/doT.js', import.meta.url), 'utf8'), crewClassicContext);
const renderCrewClassic = crewClassicContext.module.exports.template(readFileSync(new URL('../../UI/templates/crew_log.tmpl', import.meta.url), 'utf8'));
const crewClassicMarkup = renderCrewClassic({ crew: [
  { name: 'Masked sailor', job: 'Sailor' }, { name: 'NPC doctor', job: 'Doctor' },
  { name: 'Unassigned', job: '' }, { name: '&lt;img src=x&gt;', job: '&lt;script&gt;inert&lt;/script&gt;' },
] }, {}, {});
assert.ok(crewClassicMarkup.indexOf('Masked sailor') < crewClassicMarkup.indexOf('NPC doctor'));
assert.ok(crewClassicMarkup.includes('&lt;img src=x&gt;'));
assert.ok(crewClassicMarkup.includes('&lt;script&gt;inert&lt;/script&gt;'));
assert.ok(!crewClassicMarkup.includes('<img'));
assert.ok(!crewClassicMarkup.includes('<script>'));
assert.ok(!crewClassicMarkup.includes('null'));
assert.ok(renderCrewClassic({ crew: [] }, {}, {}).includes('No crew are listed.'));
const factionClassic = vm.createContext({ module: { exports: {} } });
vm.runInContext('Object.size = value => Object.keys(value).length;', factionClassic);
vm.runInContext(readFileSync(new URL('../../UI/js/libraries/doT.js', import.meta.url), 'utf8'), factionClassic);
const renderFactionClassic = factionClassic.module.exports.template(readFileSync(new URL('../../UI/templates/faction_list.tmpl', import.meta.url), 'utf8'));
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
  await update('known_languages.tmpl', { current_default: 'Common', languages: [{ name: 'Common', prefix: ':c', description: '&lt;script&gt;fictional&lt;/script&gt;', is_default: 1 }] }, 1);
  assert.ok(w.document.body.textContent.includes('Common (:c)'));
  assert.ok(w.document.body.textContent.includes('<script>fictional</script>'));
  assert.equal(w.document.querySelectorAll('li[aria-current="true"]').length, 1);
  assert.equal(w.document.querySelectorAll('script:not([src])').length, 0);
  await update('ship_stocks.tmpl', { stocks: [
    { label: 'Treasury', amount: 125, unit: 'reales' },
    { label: 'Wood', amount: 0, unit: 'logs' },
    { label: 'Water', amount: 12.5, unit: 'units' },
  ] }, 1);
  assert.equal(w.document.querySelectorAll('table[aria-label="Ship stocks"] tbody tr').length, 3);
  assert.ok(w.document.body.textContent.includes('0 logs'));
  assert.ok(w.document.body.textContent.includes('12.5 units'));
  assert.ok(w.document.body.textContent.includes('Use the book again to refresh.'));
  assert.equal(w.document.querySelectorAll('table button,table a').length, 0);
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
  await update('crew_log.tmpl', { crew: [{ name: 'Fictional sailor', job: 'Sailor' }, { name: '&lt;script&gt;inert&lt;/script&gt;', job: '' }] }, 1);
  assert.equal(w.document.querySelectorAll('table[aria-label="Crew log"] tbody tr').length, 2);
  assert.ok(w.document.body.textContent.includes('Fictional sailor'));
  assert.ok(w.document.body.textContent.includes('<script>inert</script>'));
  assert.equal(w.document.querySelectorAll('script:not([src])').length, 0);
  assert.equal(w.document.querySelectorAll('table button,table a').length, 0);
  await update('faction_list.tmpl', { factions: factionFixture }, 1);
  assert.equal(w.document.querySelectorAll('table[aria-label="Faction list"] tbody tr').length, 4);
  assert.equal(w.document.querySelectorAll('table img').length, 2);
  assert.ok(w.document.body.textContent.includes('Together & safe'));
  assert.ok(w.document.body.textContent.includes('<script>inert</script>'));
  assert.equal(w.document.querySelectorAll('table button,table a,table script').length, 0);
  await update('faction_list.tmpl', { factions: [] }, 1);
  assert.ok(w.document.body.textContent.includes('No populated factions are available.'));
  assert.equal(w.document.querySelectorAll('table img').length, 0);
  const atlasFixture = {
    query: 'ore', mode: 'graph', era: 'multiple', processor: 'sawmill', recipe_count: 1, resource_count: 1,
    resources: [{ id: '/material/ore', name: 'Indexed ore' }],
    recipes: [{ id: 'recipe-one', name: 'Fictional transformation', era_label: 'Multiple eras' }],
    detail: { id: 'recipe-one', name: 'Fictional transformation', kind: 'Combine',
      inputs: [{ id: '/material/ore', name: 'Input ore', quantity: 2 }], outputs: [],
      conditions: '&lt;script&gt;inert&lt;/script&gt;', file: 'code/game/fixture.dm', line: 12 },
  };
  await update('crafting_atlas.tmpl', atlasFixture);
  assert.equal(w.document.querySelectorAll('[data-result-type="resource"]').length, 1);
  assert.equal(w.document.querySelectorAll('[data-result-type="recipe"]').length, 1);
  assert.ok(w.document.body.textContent.includes('Input ore (2)'));
  assert.ok(w.document.body.textContent.includes('<script>inert</script>'));
  assert.equal(w.document.querySelectorAll('script:not([src])').length, 0);
  click('Indexed ore');
  assert.equal(messages.at(-1).type, 'act/atlas_navigate');
  assert.equal(messages.at(-1).payload.atlas_navigate, JSON.stringify({ route: 'resource', resource: '/material/ore' }));
  await update('crafting_atlas.tmpl', atlasFixture, 1);
  const atlasBefore = messages.length; click('Indexed ore'); assert.equal(messages.length, atlasBefore);
  await update('crafting_atlas.tmpl', { mode: 'graph', recipes: [], resources: [], recipe_count: 0, resource_count: 0 });
  assert.ok(!w.document.body.textContent.includes('Fictional transformation'));
  assert.equal(w.document.querySelectorAll('[data-result-type]').length, 0);
  click('Classic interface'); assert.equal(messages.at(-1).type, 'fallback');
  assert.deepEqual(errors, []);
  process.stdout.write("PASS: production bundle and all 16 registered routes, retained classic fixtures, handshake/action/text/fallback contracts\n");
} finally { w.close(); }
