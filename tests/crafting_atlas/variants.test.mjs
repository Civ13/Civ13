// Actual production template; DOM contract only, no BYOND/client acceptance.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const template = fs.readFileSync(new URL('../../scripts/crafting-atlas-template.html', import.meta.url), 'utf8');
class Element {
  constructor() { this.children = []; this.value = ''; this.textContent = ''; }
  append(n) { this.children.push(n); }
  replaceChildren() { this.children = []; }
  setAttribute(k, v) { this[k] = v; }
  focus() { this.focused = true; }
}
function contract(html) {
  const base = {id:'r1',name:'Arrow',kind:'Material / global',inputs:[{id:'wood',name:'wood',quantity:'1'}],outputs:[{id:'arrow',name:'arrow',quantity:'3'}],conditions:'Research archery; mode gates apply',unlock_eras:[0],era_sort:0,era_label:'Stone Age',era_basis:'archery',file:'global.txt',line:10,raw:'global source'};
  const group = {...base,variants:[{id:'r1',kind:base.kind,file:base.file,line:10,raw:base.raw},{id:'r2',kind:'Material / camp',file:'camp.txt',line:20,raw:'camp source'}]};
  const distinct = {...base,id:'r3',name:'Arrow expensive',inputs:[{id:'wood',name:'wood',quantity:'9'}],unlock_eras:[1],era_sort:1,era_label:'Bronze Age',processor:'sawmill',processor_name:'Sawmills'};
  const elements = new Map();
  const document = {getElementById(id){if(!elements.has(id))elements.set(id,new Element());return elements.get(id)},createElement(){return new Element()},createElementNS(){return new Element()}};
  const data = {sha:'fixture',recipes:[group,distinct],resources:{wood:{image:'wood.png'},arrow:{image:'arrow.png'}},limitations:[],production_sites:[],issues:[],sources:[]};
  const context=vm.createContext({document});
  vm.runInContext(html.replace('/*DATA*/',JSON.stringify(data)).match(/<script>([\s\S]*)<\/script>/i)[1],context);
  const run=s=>vm.runInContext(s,context);
  const text=n=>n.textContent+' '+n.children.map(text).join(' ');
  const selection=()=>elements.get('variants').children.find(n=>n.id==='variant');
  const filter=(id,value)=>{elements.get(id).value=value;elements.get(id)[id==='search'?'oninput':'onchange']()};
  assert.equal(elements.get('count').textContent,'2 matches','grouped count');
  assert.equal(elements.get('catalog').children.length,2,'grouped index');
  assert.equal(selection().children.length,2,'catalog options');
  for(const id of ['r2','r1','r2','r2']){
    const select=selection();select.value=id;select.onchange();
    assert.equal(selection().value,id,'repeat selection stable');
    assert(selection().focused,'keyboard focus retained after variant change');
    assert.equal(elements.get('raw').textContent,id==='r2'?'camp source':'global source','selected raw');
    assert(elements.get('source').children[0].href.endsWith(id==='r2'?'/camp.txt#L20':'/global.txt#L10'),'selected provenance');
    assert(text(elements.get('diagram')).includes(id==='r2'?'Material / camp':'Material / global'),'selected transformation');
    assert(text(elements.get('diagram')).includes('3 × arrow'),'output quantity');
  }
  filter('kind','Material / global');
  assert.equal(selection().value,'r1','kind filter replaces excluded variant');
  filter('search','camp.txt');
  assert.equal(elements.get('count').textContent,'0 matches','query and kind apply to same variant');
  assert.equal(elements.get('variants').children.length,0,'empty filter clears selector');
  assert.equal(elements.get('source').children.length,0,'empty filter clears source');
  elements.get('reset').onclick();elements.get('catalog').children[0].onclick();
  filter('search','camp.txt');
  assert.equal(elements.get('count').textContent,'1 matches');
  assert.equal(selection().value,'r2','path search selects matching catalog');
  assert.equal(selection().children.length,1,'only matching variants available');
  elements.get('reset').onclick();
  filter('era','1');
  assert.equal(elements.get('title').textContent,'Arrow expensive','era filter replaces whole group');
  assert.equal(elements.get('variants').children.length,0,'single recipe clears selector');
  assert(text(elements.get('diagram')).includes('9 × wood'),'distinct input quantity');
  elements.get('reset').onclick();elements.get('catalog').children[0].onclick();
  run('resource("wood")');
  assert.equal(elements.get('variants').children.length,0,'resource navigation clears selector');
  assert.equal(elements.get('relations').children.filter(n=>n.onclick).length,2,'one relation per group');
  elements.get('relations').children.find(n=>n.onclick).onclick();
  assert.equal(selection().value,'r1','return selects available catalog');
  filter('processor','sawmill');
  assert.equal(elements.get('title').textContent,'Arrow expensive');
  assert.equal(elements.get('variants').children.length,0,'processor filter clears selector');
}
contract(template);
const wrongSource=template.replace('srcLink(r.file,r.line', 'srcLink(group.file,group.line');
assert.notEqual(wrongSource,template);
assert.throws(()=>contract(wrongSource),/selected provenance/);
const siblingSearch=template.replace('variants:undefined','variants:r.variants');
assert.notEqual(siblingSearch,template);
assert.throws(()=>contract(siblingSearch),/query and kind apply to same variant/);
console.log('PASS: grouped counts/relations, accessible selector, repeated selection, quantities, exact source/raw, kind/path/era/processor filters, empty/reset/resource navigation and two omission controls.');
