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
  assert.equal(elements.get('count').textContent,'2 recipe matches','grouped count');
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
  assert.equal(elements.get('count').textContent,'0 recipe matches · 0 resource matches','query and kind apply to same variant');
  assert.equal(elements.get('variants').children.length,0,'empty filter clears selector');
  assert.equal(elements.get('source').children.length,0,'empty filter clears source');
  elements.get('reset').onclick();elements.get('catalog').children[0].onclick();
  filter('search','camp.txt');
  assert.equal(elements.get('count').textContent,'1 recipe matches · 0 resource matches');
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


function familyContract(html) {
  const family='family_'+'a'.repeat(24),other='family_'+'b'.repeat(24);
  const base={id:'r1',name:'fur gloves',family_id:family,kind:'Material / global',inputs:[{id:'foxpelt',name:'fox pelt',quantity:'3'}],outputs:[{id:'brown',name:'brown gloves',quantity:'1'}],conditions:'Fox route; locked node still required',unlock_eras:[0],era_sort:0,era_label:'Stone Age',era_basis:'Research node',file:'global.txt',line:10,raw:'fox source'};
  const first={...base,variants:[{id:'r1',kind:base.kind,file:base.file,line:10,raw:base.raw},{id:'r2',kind:'Material / camp',file:'camp.txt',line:20,raw:'camp fox source'}]};
  const bison={...base,id:'r3',inputs:[{id:'bisonpelt',name:'bison pelt',quantity:'9'}],conditions:'Bison route; another map may be unavailable',line:30,raw:'bison source'};
  const white={...base,id:'r4',outputs:[{id:'white',name:'white gloves',quantity:'2'}],unlock_eras:[1],era_sort:1,era_label:'Bronze Age',line:40,raw:'white source'};
  const unrelated={...base,id:'r5',family_id:other,outputs:[{id:'unrelated',name:'unrelated product',quantity:'1'}],line:50,raw:'separate source'};
  const recipes=[first,bison,white,unrelated];
  const resources=Object.fromEntries(recipes.flatMap(r=>r.inputs.concat(r.outputs)).map(x=>[x.id,{image:'local.png',label:x.name}]));
  const elements=new Map(),document={getElementById(id){if(!elements.has(id))elements.set(id,new Element());return elements.get(id)},createElement(){return new Element()},createElementNS(){return new Element()}};
  const data={sha:'fixture',recipes,resources,limitations:[],production_sites:[],issues:[],sources:[]};
  const context=vm.createContext({document});
  vm.runInContext(html.replace('/*DATA*/',JSON.stringify(data)).match(/<script>([\s\S]*)<\/script>/i)[1],context);
  const run=s=>vm.runInContext(s,context),text=n=>n.textContent+' '+n.children.map(text).join(' ');
  const familySelection=()=>elements.get('variants').children.find(n=>n.id==='recipe-variant');
  const catalogSelection=()=>elements.get('variants').children.find(n=>n.id==='variant');
  const choose=id=>{const select=familySelection();select.value=id;select.onchange()};
  const filter=(id,value)=>{elements.get(id).value=value;elements.get(id)[id==='search'?'oninput':'onchange']()};
  assert.equal(elements.get('catalog').children.length,2,'family count on the left');
  assert.equal(elements.get('count').textContent,'2 recipe families / 4 recipe matches','families and retained recipe counts');
  assert.equal(familySelection().children.length,3,'all related recipe variants on the right');
  assert.equal(catalogSelection().children.length,2,'separate equivalent catalog choices');
  assert(text(familySelection()).includes('9 x bison pelt'),'variant input costs distinguish same-output recipes');
  choose('r3');
  assert.equal(elements.get('raw').textContent,'bison source','selected family recipe source');
  assert(text(elements.get('diagram')).includes('9 \u00d7 bisonpelt'),'selected family recipe quantity: '+text(elements.get('diagram')));
  assert(elements.get('conditions').textContent.includes('another map may be unavailable'),'unavailable requirements preserved');
  assert.equal(familySelection().value,'r3','selected family identity');
  assert(familySelection().focused,'family keyboard focus retained');
  choose('r1');const catalog=catalogSelection();catalog.value='r2';catalog.onchange();
  assert.equal(elements.get('raw').textContent,'camp fox source','canonical catalog alias retained');
  assert.equal(familySelection().value,'r1','family choice stable while selecting catalog alias');
  assert.equal(catalogSelection().value,'r2');
  choose('r4');assert(text(elements.get('diagram')).includes('2 \u00d7 white'),'selected output quantity');
  assert(elements.get('conditions').textContent.includes('Bronze Age'),'selected unlock details');
  choose('not-a-recipe');assert.equal(elements.get('raw').textContent,'white source','unknown UI value ignored');
  filter('era','0');assert.equal(familySelection().children.length,2,'era filters each recipe before grouping');
  assert(!text(familySelection()).includes('white gloves'),'excluded era option removed');
  filter('kind','Material / camp');assert.equal(catalogSelection().value,'r2','kind and family filters preserve alias');
  assert.equal(familySelection(),undefined,'one filtered recipe needs no family chooser');
  elements.get('reset').onclick();filter('search','bisonpelt');
  assert.equal(elements.get('catalog').children.filter(n=>n['data-result-type']==='recipe').length,1,'ingredient search keeps exact variant');
  assert.equal(elements.get('raw').textContent,'bison source','search selects matching member rather than a sibling');
  filter('search','family_');assert.equal(elements.get('catalog').children.length,0,'presentation metadata is not searchable gameplay');
  assert.equal(elements.get('variants').children.length,0,'empty search clears both selectors');
  elements.get('reset').onclick();run('resource("brown")');
  assert.equal(elements.get('variants').children.length,0,'resource navigation clears family choice');
  elements.get('relations').children.find(n=>n.onclick).onclick();
  assert.equal(familySelection().children.length,2,'resource query includes only variants using that exact resource');
  run("D.recipes=Array.from({length:300},(_,i)=>({...D.recipes[0],id:'r'+(1000+i),variants:undefined,family_id:'one-complete-family'}))");
  elements.get('reset').onclick();
  assert.equal(elements.get('catalog').children.filter(n=>n['data-result-type']==='recipe').length,1,'large family still one left entry');
  assert.equal(familySelection().children.length,300,'complete matching family retained beyond the index bound');
  assert(!text(elements.get('catalog')).includes('Showing the first 250'),'no recipe-row truncation warning for one family');
  run("D.recipes=D.recipes.map((r,i)=>({...r,family_id:'distinct-'+i}))");
  elements.get('reset').onclick();
  assert.equal(elements.get('catalog').children.filter(n=>n['data-result-type']==='recipe').length,250,'family result bound remains 250');
  assert(text(elements.get('catalog')).includes('Showing the first 250 recipe families'),'family bound explained');
}
familyContract(template);
const missingFamily=template.replace("r.family_id||('recipe_'+r.id)","('recipe_'+r.id)");
assert.notEqual(missingFamily,template);
assert.throws(()=>familyContract(missingFamily),/family count on the left/);
const searchableFamily=template.replace(',family_id:undefined','');
assert.notEqual(searchableFamily,template);
assert.throws(()=>familyContract(searchableFamily),/presentation metadata is not searchable gameplay/);
console.log('PASS: screenshot family consolidation, distinct input costs, canonical aliases, selected quantities/unlocks/source, independent filters, unknown values, focus, reset/resource flow and two family negative controls.');

const missingFamilyBound=template.replace('[...families.values()].slice(0,250)','[...families.values()]');
assert.notEqual(missingFamilyBound,template);
assert.throws(()=>familyContract(missingFamilyBound),/family result bound remains 250/);
const truncatedMembers=template.replace('filteredRecipes=rs;','filteredRecipes=rs.slice(0,250);');
assert.notEqual(truncatedMembers,template);
assert.throws(()=>familyContract(truncatedMembers),/complete matching family retained/);
console.log('PASS: 250-family bound, complete 300-member selected family and two bound omission controls.');
