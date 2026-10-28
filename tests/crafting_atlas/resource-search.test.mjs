// Production template and real catalog. DOM/data evidence, no native game/browser.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const root=new URL('../../',import.meta.url);
const template=fs.readFileSync(new URL('scripts/crafting-atlas-template.html',root),'utf8');
const catalog=JSON.parse(fs.readFileSync(new URL('UI/crafting-atlas.json',root),'utf8'));
class Element {
  constructor(){this.children=[];this.value='';this.textContent='';}
  append(n){this.children.push(n);} replaceChildren(){this.children=[];}
  setAttribute(k,v){this[k]=v;} focus(){}
}
function boot(data,html=template){
  const elements=new Map();
  const document={getElementById(id){if(!elements.has(id))elements.set(id,new Element());return elements.get(id)},createElement(){return new Element()},createElementNS(){return new Element()}};
  const context=vm.createContext({document});
  const run=s=>vm.runInContext(s,context,{timeout:10000});
  run(html.replace('/*DATA*/',JSON.stringify({...data,sha:'offline-contract',production_sites:[],issues:[],sources:[],limitations:[]})).match(/<script>([\s\S]*)<\/script>/i)[1]);
  const get=id=>elements.get(id);
  const filter=(id,value)=>{get(id).value=value;get(id)[id==='search'?'oninput':'onchange']()};
  const rows=type=>get('catalog').children.filter(n=>n['data-result-type']===type);
  return {get,filter,rows,run};
}
const text=n=>n.textContent+' '+n.children.map(text).join(' ');
function realContract(html=template){
  const {get,filter,rows,run}=boot(catalog,html);
  const id='proteolytic_enzyme',name='proteolytic enzyme';
  for(const query of [id,name,'PROTEOLYTIC_ENZYME','  proteolytic\t enzyme  ','proteolytic  enzyme','proteolytic']){
    filter('search',query);
    assert.equal(rows('resource').length,1,'direct resource result');
    assert.equal(rows('resource')[0].textContent,name);
    assert(text(rows('resource')[0]).includes('Resource · '+id),'canonical identity and type label');
    assert.deepEqual(rows('recipe').map(n=>n.textContent),['Biological extraction kit','Gelatin - digestive protease treatment'],'recipe results retained');
    assert(rows('recipe').every(n=>text(n).includes('Recipe · ')),'distinct recipe type labels');
  }
  filter('kind','Chemistry');filter('era','8');filter('processor','sawmill');
  assert.equal(rows('recipe').length,0);
  assert.equal(rows('resource').length,1,'recipe filters cannot hide a resource match');
  rows('resource')[0].onclick();
  for(const id of ['kind','era','processor'])assert.equal(get(id).value,'','resource navigation clears '+id);
  assert.equal(get('search').value,id,'canonical identity retained');
  assert.equal(get('title').textContent,name);
  assert(text(get('obtain')).includes('Use an empty extraction kit on a vomit decal'),'direct acquisition navigation');
  assert(text(get('relations')).includes('Produces: Biological extraction kit'));
  assert(text(get('relations')).includes('Uses: Gelatin - digestive protease treatment'));
  assert.equal(get('diagram').children.length,0,'resource clears stale recipe diagram');
  assert.equal(get('source').children.length,0);assert.equal(get('raw').textContent,'');
  get('relations').children.find(n=>n.textContent==='Produces: Biological extraction kit').onclick();
  assert.equal(get('title').textContent,'Biological extraction kit');
  assert.equal(get('diagram').children.length,1,'producer recipe remains selectable');
  filter('search',id);rows('resource')[0].onclick();
  filter('search','no-such-resource-or-recipe');
  assert.equal(rows('resource').length,0);assert.equal(rows('recipe').length,0);
  for(const key of ['obtain','relations','diagram','source','variants'])assert.equal(get(key).children.length,0,'no match clears '+key);
  assert.equal(get('raw').textContent,'');assert.equal(get('conditions').textContent,'');
  filter('search',id);rows('resource')[0].onclick();filter('search','  \t _  ');
  assert.equal(rows('resource').length,0,'normalized empty query keeps recipe browsing');
  assert.equal(rows('recipe').length,250,'empty query retains bounded browse');
  assert.equal(get('obtain').children.length,0,'empty query clears stale acquisition');
  filter('search',id);rows('resource')[0].onclick();get('reset').onclick();
  assert.equal(get('search').value,'');assert.equal(get('obtain').children.length,0);
  filter('search','Digestive Protease');
  assert.equal(rows('resource').length,0,'no speculative reagent alias');
  assert.equal(rows('recipe').length,1);
  filter('search','Biological extraction kit');
  assert.equal(rows('recipe').length,3,'same-name recipes with different outputs remain distinct');
  assert.equal(catalog.resources[id].name,name,'catalog label unchanged');
  assert.equal(run('selectedResource'),null);
}
realContract();
const sand=boot(catalog);
sand.run('resource("/turf/floor/beach/sand")');
assert(text(sand.get('obtain')).includes('Gathering from sand'));
assert(text(sand.get('obtain')).includes('Shovel sand'));
assert(text(sand.get('obtain')).includes('non-harm'));
sand.run('resource("/obj/item/stack/ore/glass")');
assert(text(sand.get('obtain')).includes('How to obtain sand'));
assert(text(sand.get('obtain')).includes('Shovel sand'));
assert.notEqual('/turf/floor/beach/sand','/obj/item/stack/ore/glass');
const resourceOmission=template.replace('rr.slice(0,150)','rr.slice(0,0)');
assert.notEqual(resourceOmission,template);
assert.throws(()=>realContract(resourceOmission),/direct resource result/);
const normalizationOmission=template.replace(String.raw`.replace(/_/g,' ').replace(/\s+/g,' ').trim()`,'');
assert(normalizationOmission!==template,'normalization mutation applied');
assert.throws(()=>realContract(normalizationOmission),/direct resource result/);

const recipe=(id,name,resource)=>({id,name,kind:'Fixture',inputs:[{id:resource,name:'Shared label',quantity:'1'}],outputs:[{id:'output',name:'Product',quantity:'1'}],file:'fixture.dm',line:1,raw:'source '+id,conditions:'Fixture',unlock_eras:[0],era_sort:0,era_label:'Stone Age',era_basis:'Fixture'});
const sameName={recipes:[recipe('a','Shared label','first_id'),recipe('b','Shared label','second_id')],resources:{first_id:{name:'Shared label'},second_id:{name:'Shared label'},orphan_id:{name:'Orphan resource'},output:{name:'Product'}}};
const collision=boot(sameName);
collision.filter('search','Shared_label');
assert.equal(collision.rows('resource').length,2,'same resource labels keep both canonical IDs');
assert.equal(collision.rows('recipe').length,2,'resource and recipe names do not merge identities');
collision.rows('resource')[1].onclick();
assert.equal(collision.get('search').value,'second_id');
collision.filter('search','orphan_id');collision.rows('resource')[0].onclick();
assert.equal(collision.get('title').textContent,'Orphan resource');
assert(text(collision.get('obtain')).includes('No reviewed gathering instructions'));

const large={recipes:Array.from({length:260},(_,i)=>recipe('r'+i,'Bounded recipe '+i,'bounded_'+i)),resources:Object.fromEntries(Array.from({length:160},(_,i)=>['bounded_'+i,{name:'Bounded resource '+i}]))};
// Rendering these synthetic recipe cards only needs metadata for the first input/output.
large.resources.output={name:'Product'};
const bounded=boot(large);bounded.filter('search','bounded');
assert.equal(bounded.rows('resource').length,150,'independent resource bound');
assert.equal(bounded.rows('recipe').length,250,'independent recipe bound');
assert.equal(bounded.get('count').textContent,'260 recipe matches · 160 resource matches');
assert(text(bounded.get('catalog')).includes('first 150 resource matches'));
assert(text(bounded.get('catalog')).includes('first 250 matches'));
console.log('PASS: direct resource/name/ID search, normalization and omission controls, distinct identities/types, independent bounds, filter clearing, acquisition/producer navigation, empty/no-match/reset and unchanged labels/variants; offline DOM only.');
