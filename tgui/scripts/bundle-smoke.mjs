// Executes the production bundle with real tgui-core/React in an isolated DOM.
// This verifies application wiring, not layout pixels or native BYOND behavior.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { JSDOM, VirtualConsole } from 'jsdom';
const factionFixture = [
  { name: 'First', motto: 'Together &amp; safe', flavour: '&lt;script&gt;inert&lt;/script&gt;', members: 1, symbol: 'flist_first.png' },
  { name: 'Second', members: 2, symbol: '' },
  { name: '&lt;img src=x&gt;', members: 3, symbol: 'https://example.com/a.png' },
  { name: 'Unicode symbol', members: 4, symbol: 'flist_ÐºÐ¸Ñ€Ð¸Ð»Ð»Ð¸Ñ†Ð°.png' },
];
const photoFixture = { name: 'Sand &amp; sea', image: 'tmp_photo_12.png', width: 448, scribble: '&lt;script&gt;inert&lt;/script&gt; &amp; a boat.' };
const errors = [];
const console = new VirtualConsole(); console.on('jsdomError', error => errors.push(error.message));
const dom = new JSDOM('<!doctype html><body data-ref="[0x123]" data-window="main[0x456]" data-generation="2"><div id="root"></div><p id="tgui-loading">Loading...</p></body>', { runScripts: 'outside-only', url: 'http://127.0.0.1/', virtualConsole: console });
const w = dom.window, messages = [];
Object.defineProperty(w.navigator, 'userAgent', { value: 'Chrome/130.0 (JSDOM fixture)' });
w.fetch = (...args) => globalThis.fetch(...args);
w.cef_to_byond = url => {
  const params = new URL(url).searchParams;
  messages.push({ type: params.get('type'), payload: params.has('payload') ? JSON.parse(params.get('payload')) : undefined });
};
w.eval(readFileSync(new URL('../../UI/tgui/civ13-tgui-bootstrap.js', import.meta.url), 'utf8'));
const settle = () => new Promise(resolve => setTimeout(resolve, 40));
const waitFor = async (predicate, message) => {
  const deadline = Date.now() + 2000;
  while (!predicate() && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 10));
  assert.ok(predicate(), message);
};
const update = async (template, data, status = 2) => { w.receiveUpdateData(JSON.stringify({ config: { template, title: 'Civ13', status, ref: '[0x123]', window: 'main[0x456]', generation: 2 }, data })); await settle(); };
const click = text => {
  const el = [...w.document.querySelectorAll('.Button,button')].find(el => el.textContent === text);
  assert.ok(el, `Missing control ${text}`);
  el.dispatchEvent(new w.MouseEvent('click', { bubbles: true }));
};
// Atlas result rows carry a name and a caption in one control.
const clickRow = text => {
  const el = [...w.document.querySelectorAll('button.atlas-row')].find(el => el.querySelector('strong')?.textContent === text);
  assert.ok(el, `Missing atlas row ${text}`);
  el.dispatchEvent(new w.MouseEvent('click', { bubbles: true }));
};
try {
  w.eval(readFileSync(new URL('../../UI/tgui/civ13-tgui.js', import.meta.url), 'utf8'));
  await waitFor(() => messages[0]?.type === 'ready', 'Production bundle did not signal ready');
  assert.notEqual(w.document.getElementById('tgui-loading').style.display, 'none');
  await update('chem_disp.tmpl', { amount: 5, chemicals: [{ title: 'Water', id: 'water' }] });
  assert.equal(messages[1]?.type, 'ack');
  assert.equal(w.document.getElementById('tgui-loading').style.display, 'none');
  w.receiveUpdateData(JSON.stringify({ config: { template: 'warehouse_book.tmpl', ref: '[0x123]', window: 'main[0x456]', generation: 1, status: 2 }, data: { items: [{ name: 'STALE GENERATION', amount: 99 }] } }));
  await settle(); assert.ok(!w.document.body.textContent.includes('STALE GENERATION'));
  click('Water'); assert.equal(messages.at(-1).type, 'act/dispense'); assert.equal(messages.at(-1).payload.value, 'water');
  await update('chem_disp.tmpl', { amount: 5, chemicals: [{ title: 'Water', id: 'water' }] }, 1);
  const before = messages.length; click('Water'); assert.equal(messages.length, before);
  for (const template of ['appearance_changer.tmpl', 'vending_machine.tmpl', 'vending_machine2.tmpl', 'vending_machine_gulag.tmpl', 'vending_machine_taotd.tmpl', 'warehouse_book.tmpl', 'faction_symbol.tmpl', 'faction_creation.tmpl', 'research_bench.tmpl', 'wiremod_circuit.tmpl']) {
    await update(template, {}); assert.ok(!messages.some(message => message.type === 'fallback'), `Render failed: ${template}`);
  }
  await update('wiremod_circuit.tmpl', {
    on: 1, display_name: 'Integrated circuit', grid_mode: 1, screen_x: 0, screen_y: 0,
    stored_designs: { '/obj/item/circuit_component/operator/arithmetic': true },
    component_catalog: [{
      type: '/obj/item/circuit_component/operator/arithmetic',
      name: 'Arithmetic',
      description: 'Performs arithmetic.',
      category: 'Math',
      input_ports: [],
      output_ports: [],
    }],
    components: [],
  });
  const wiremodButtons = w.document.querySelectorAll('.wiremod-window__buttons .Button');
  assert.ok(wiremodButtons.length >= 2, 'Original circuit editor toolbar did not render');
  wiremodButtons[1].dispatchEvent(new w.MouseEvent('click', { bubbles: true }));
  await waitFor(() => w.document.body.textContent.includes('Component Menu'), 'Original component menu did not open');
  await waitFor(() => w.document.body.textContent.includes('Arithmetic'), 'Civ13 core catalog did not load');
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
  assert.ok(w.document.body.textContent.includes('Input ore(2)'));
  assert.ok(w.document.body.textContent.includes('<script>inert</script>'));
  assert.equal(w.document.querySelectorAll('script:not([src])').length, 0);
  clickRow('Indexed ore');
  assert.equal(messages.at(-1).type, 'act/atlas_navigate');
  assert.equal(messages.at(-1).payload.value, JSON.stringify({ route: 'resource', resource: '/material/ore' }));
  await update('crafting_atlas.tmpl', atlasFixture, 1);
  const atlasBefore = messages.length; clickRow('Indexed ore'); assert.equal(messages.length, atlasBefore);
  await update('crafting_atlas.tmpl', { mode: 'graph', recipes: [], resources: [], recipe_count: 0, resource_count: 0 });
  assert.ok(!w.document.body.textContent.includes('Fictional transformation'));
  assert.equal(w.document.querySelectorAll('[data-result-type]').length, 0);
  await update('character_flavor.tmpl', { name: 'Fictional subject', text: 'First\n\u65e5\u672c\u8a9e \ud83d\ude00 &#10; &amp;lt;b&amp;gt; &lt;img src=x&gt;' }, 1);
  const flavor = w.document.querySelector('article.character-flavor');
  assert.ok(flavor.textContent.includes('\u65e5\u672c\u8a9e \ud83d\ude00 \n &lt;b&gt; <img src=x>'));
  assert.equal(flavor.querySelectorAll('br').length, 1);
  assert.equal(flavor.querySelectorAll('img,script,a,button,input').length, 0);
  await update('character_flavor.tmpl', { name: 'Second subject', text: '' }, 1);
  assert.equal(w.document.querySelector('article.character-flavor').textContent, '');
  assert.ok(!w.document.body.textContent.includes('Fictional subject'));
  const note = (text, bold = 0, italic = 0) => ({ text, bold, italic });
  const notes = { character: [note('Fictional ghost')], sections: [{ title: [note('Role')], entries: [{ runs: [note('Guard', 1), { br: 1 }, note('the gate', 0, 1)] }] }], memory: [note('\u65e5\u672c\u8a9e \ud83d\ude00 &amp;lt;b&amp;gt; &lt;img src=x&gt;')], discoveries: [note('Discoveries', 1), { br: 1 }, note('Public observation')] };
  await update('character_notes.tmpl', notes, 1);
  assert.ok(w.document.body.textContent.includes('You are Fictional ghost'));
  assert.ok(w.document.body.textContent.includes('\u65e5\u672c\u8a9e \ud83d\ude00 &lt;b&gt; <img src=x>'));
  assert.equal(w.document.querySelectorAll('article strong').length, 3);
  assert.equal(w.document.querySelectorAll('article br').length, 2);
  assert.equal(w.document.querySelectorAll('article button,article a,article input,article img,article script').length, 0);
  await update('character_notes.tmpl', { character: [note('Reopened owner')], sections: [], memory: [note('No memories stored.')], discoveries: [note('No discoveries recorded.')] }, 1);
  assert.ok(!w.document.body.textContent.includes('Guard'));
  assert.ok(w.document.body.textContent.includes('Reopened owner'));
  await update('photo_viewer.tmpl', photoFixture, 1);
  assert.equal(w.document.querySelector('.photo-viewer img').getAttribute('src'), 'tmp_photo_12.png');
  assert.equal(w.document.querySelector('.photo-viewer img').width, 448);
  assert.ok(w.document.body.textContent.includes('<script>inert</script> & a boat.'));
  assert.equal(w.document.querySelectorAll('.photo-viewer script,.photo-viewer [onerror],.photo-viewer button,.photo-viewer a').length, 0);
  await update('photo_viewer.tmpl', { name: 'Empty', image: '', scribble: '' }, 1);
  assert.equal(w.document.querySelectorAll('.photo-viewer img,.photo-viewer em').length, 0);
  assert.ok(!w.document.body.textContent.includes('inert'));
  // There is one renderer: no control offers another interface.
  assert.ok(![...w.document.querySelectorAll('.Button,button')].some(el => /classic/i.test(el.textContent)));
  assert.ok(!messages.some(message => message.type === 'fallback'));
  assert.deepEqual(errors, []);
  process.stdout.write("PASS: production bundle and 20 retained routes, retained photo/Notes/flavor fixtures, inert text/snapshot replacement, handshake/action/text/image/fallback contracts\n");
} finally { w.close(); }

// Preserve this reviewed reader recovery in its own fresh root.
{
const recovery = new JSDOM('<body data-ref="[0x123]" data-window="main[0x456]" data-generation="2"><div id="root"></div><p id="tgui-loading"></p>', { runScripts: 'outside-only', url: 'http://127.0.0.1/', virtualConsole: new VirtualConsole() });
try {
  const rw = recovery.window, sent = [];
  Object.defineProperty(rw.navigator, 'userAgent', { value: 'Chrome/130.0 (JSDOM fixture)' });
  rw.cef_to_byond = url => sent.push(new URL(url).searchParams.get('type'));
  rw.eval(readFileSync(new URL('../../UI/tgui/civ13-tgui-bootstrap.js', import.meta.url), 'utf8'));
  rw.eval(readFileSync(new URL('../../UI/tgui/civ13-tgui.js', import.meta.url), 'utf8'));
  await waitFor(() => sent.includes('ready'), 'Production flavor bundle did not signal ready');
  rw.receiveUpdateData(JSON.stringify({ config: { template: 'character_flavor.tmpl', status: 1, ref: '[0x123]', window: 'main[0x456]', generation: 2 }, data: { name: 'Fictional subject', text: 'PARTIAL\n<b>unsupported</b>' } }));
  await settle();
  assert.equal(sent.filter(type => type === 'fallback').length, 1);
  assert.ok(!rw.document.body.textContent.includes('PARTIAL'));
  process.stdout.write('PASS: fresh flavor production root rejects a mixed malformed snapshot through the real bootstrap fallback\n');
} finally { recovery.window.close(); }

}

// Preserve this reviewed reader recovery in its own fresh root.
{
const recovery = new JSDOM('<body data-ref="[0x123]" data-window="main[0x456]" data-generation="2"><div id="root"></div><p id="tgui-loading"></p>', { runScripts: 'outside-only', url: 'http://127.0.0.1/', virtualConsole: new VirtualConsole() });
try {
  const rw = recovery.window, sent = [];
  Object.defineProperty(rw.navigator, 'userAgent', { value: 'Chrome/130.0 (JSDOM fixture)' });
  rw.cef_to_byond = url => sent.push(new URL(url).searchParams.get('type'));
  rw.eval(readFileSync(new URL('../../UI/tgui/civ13-tgui-bootstrap.js', import.meta.url), 'utf8'));
  rw.eval(readFileSync(new URL('../../UI/tgui/civ13-tgui.js', import.meta.url), 'utf8'));
  await waitFor(() => sent.includes('ready'), 'Production notes bundle did not signal ready');
  rw.receiveUpdateData(JSON.stringify({ config: { template: 'character_notes.tmpl', status: 1, ref: '[0x123]', window: 'main[0x456]', generation: 2 }, data: { character: [], sections: [], memory: [{ text: '<b>UNSAFE_PARTIAL</b>', bold: 0, italic: 0 }], discoveries: [] } }));
  await settle();
  assert.equal(sent.filter(type => type === 'fallback').length, 1);
  assert.ok(!rw.document.body.textContent.includes('UNSAFE_PARTIAL'));
  assert.ok(rw.document.body.textContent.includes('This window could not be shown'));
  process.stdout.write('PASS: fresh production Notes root rejects malformed content through real bootstrap fallback; cached server HTML verified separately by source contracts\n');
} finally { recovery.window.close(); }

}

await import('./book-bundle-smoke.mjs');
