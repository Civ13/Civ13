// Execute the production website template against the actual game catalog.
// DOM/data evidence only: no browser, image export, BYOND or client acceptance.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const root = new URL('../../', import.meta.url);
const catalog = JSON.parse(fs.readFileSync(new URL('UI/crafting-atlas.json', root), 'utf8'));
const template = fs.readFileSync(new URL('scripts/crafting-atlas-template.html', root), 'utf8');
class Element {
  constructor() { this.children = []; this.value = ''; this.textContent = ''; }
  append(n) { this.children.push(n); }
  replaceChildren() { this.children = []; }
  setAttribute(k, v) { this[k] = v; }
}
const elements = new Map();
const document = { getElementById(id) { if (!elements.has(id)) elements.set(id, new Element()); return elements.get(id); },
  createElement() { return new Element(); }, createElementNS() { return new Element(); } };
const data = { ...catalog, sha: 'catalog-contract', production_sites: [], issues: [], sources: [], limitations: [] };
const context = vm.createContext({ document });
vm.runInContext(template.replace('/*DATA*/', JSON.stringify(data)).match(/<script>([\s\S]*)<\/script>/i)[1], context, { timeout: 10000 });
const run = s => vm.runInContext(s, context, { timeout: 10000 });
const text = n => n.textContent + ' ' + n.children.map(text).join(' ');
const search = query => { elements.get('search').value = query; elements.get('search').oninput(); };

assert(elements.get('processor').children.some(x => x.value === 'tanning_rack'));
elements.get('processor').value = 'tanning_rack';
elements.get('processor').onchange();
assert.equal(elements.get('count').textContent, '1 recipe matches');
elements.get('catalog').children[0].onclick();
assert.equal(elements.get('title').textContent, 'Rack-dry washed hides');
assert(elements.get('conditions').textContent.includes('resource_processing'));
assert(elements.get('conditions').textContent.includes('300 ticks'));
assert(text(elements.get('diagram')).includes('station; not consumed'));
const station = elements.get('relations').children.find(x => x.textContent === 'tanning rack');
assert(station, 'rack construction resource link'); station.onclick();
assert.equal(elements.get('processor').value, '', 'resource navigation clears processor filter');
assert(text(elements.get('relations')).includes('Produces: tanning rack'));

for (const id of ['/material/rawhide', '/material/hairlesshide', '/material/wethide', '/material/dryhide', '/material/leather', '/obj/item/stack/bark', 'tannin']) {
  run('resource('+JSON.stringify(id)+')');
  assert(text(elements.get('obtain')).includes('Steps:'), id+' acquisition instructions');
  assert(text(elements.get('relations')).includes('Produces:'), id+' producer navigation');
  assert(text(elements.get('relations')).includes('Uses:'), id+' consumer navigation');
}
search('Harvest adult turkey hen skin');
assert.equal(elements.get('count').textContent, '1 recipe matches · 0 resource matches');
elements.get('catalog').children[0].onclick();
assert(text(elements.get('diagram')).includes('raw hide'));
assert(elements.get('conditions').textContent.includes('chicks give no hide'));
search('Extract bark tannin');
elements.get('catalog').children[0].onclick();
assert(text(elements.get('diagram')).includes('10 \u00d7 water'));
assert(text(elements.get('diagram')).includes('10 \u00d7 tannin'));
assert.equal(elements.get('source').children[0].href.includes('leather.dm#L'), true);
console.log('PASS: actual tanning catalog search, station construction, processor filter, all stage producer/consumer links, acquisition instructions and paid quantities. DOM contract only; images and native/client UI unverified.');
