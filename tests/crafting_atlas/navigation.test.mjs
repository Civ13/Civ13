import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const template = fs.readFileSync(new URL('../../scripts/crafting-atlas-template.html', import.meta.url), 'utf8');
class Element {
  constructor() { this.children = []; this.value = ''; this.textContent = ''; }
  append(n) { this.children.push(n); }
  replaceChildren() { this.children = []; }
  setAttribute(k, v) { this[k] = v; }
}
const ingredient = { id: 'wood', name: '<wood>', quantity: '1' };
const recipes = [
  { name: 'Unknown', unlock_eras: [], era_sort: 99 },
  { name: 'Multi', unlock_eras: [1, 4], era_sort: 1 },
  { name: 'Primitive sawmill', unlock_eras: [1], era_sort: 1, processor: 'sawmill', processor_name: 'Sawmills' },
  { name: 'Modern', unlock_eras: [8], era_sort: 8 },
].map((r, i) => ({ id: 'r' + i, kind: 'Fixture', inputs: [ingredient], outputs: [{ ...ingredient, id: 'planks', quantity: '4 nominal' }], era_label: 'Fixture tier', era_basis: 'Research fixture', conditions: 'Conditional', file: 'fixture.dm', line: 1, raw: '', ...r }));
const data = { sha: 'fixture', recipes, resources: { wood: { image: 'fixture.png' }, planks: { image: 'fixture.png' } }, limitations: [], production_sites: [], issues: [], sources: [], acquisition: {} };

function contract(html) {
  const elements = new Map();
  const document = { getElementById(id) { if (!elements.has(id)) elements.set(id, new Element()); return elements.get(id); }, createElement() { return new Element(); }, createElementNS() { return new Element(); } };
  const context = vm.createContext({ document });
  vm.runInContext(html.replace('/*DATA*/', JSON.stringify(data)).match(/<script>([\s\S]*)<\/script>/i)[1], context);
  const result = () => Array.from(vm.runInContext('filter().map(r=>r.name)', context));
  assert.deepEqual(result(), ['Multi', 'Primitive sawmill', 'Modern', 'Unknown'], 'era sorting');
  elements.get('era').value = '4';
  assert.deepEqual(result(), ['Multi'], 'era membership');
  elements.get('era').value = 'unknown';
  assert.deepEqual(result(), ['Unknown'], 'unknown era');
  elements.get('era').value = 'multiple';
  assert.deepEqual(result(), ['Multi'], 'multiple eras');
  elements.get('reset').onclick();
  elements.get('processor').value = 'sawmill';
  assert.deepEqual(result(), ['Primitive sawmill'], 'processor membership');
  elements.get('catalog').children[0].onclick();
  assert(elements.get('conditions').textContent.includes('Research fixture'));
  assert(elements.get('diagram').children.length === 1);
  elements.get('relations').children.find(n=>n.onclick).onclick();
  assert.equal(elements.get('processor').value, '');
  assert.equal(elements.get('era').value, '');
  assert(elements.get('catalog').children.length === 4, 'resource navigation resets restrictive filters');
  elements.get('search').value = 'absent';
  assert.deepEqual(result(), [], 'empty search');
  elements.get('reset').onclick();
  elements.get('catalog').children[0].onclick();
  elements.get('search').value = 'absent';
  result();
  assert.equal(elements.get('diagram').children.length, 0, 'empty filter clears stale diagram');
}
contract(template);
const badEra = template.replace('r.unlock_eras.includes(Number(e))', 'true');
assert.notEqual(badEra, template);
assert.throws(() => contract(badEra), /era membership/);
const badProcessor = template.replace('!p||r.processor===p', 'true');
assert.notEqual(badProcessor, template);
assert.throws(() => contract(badProcessor), /processor membership/);
console.log('PASS: template sorting, era/multiple/unknown/processor filtering, diagram selection, resource navigation, reset and two omission controls; DOM contract, no browser visual claim.');
