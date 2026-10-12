import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const root=process.argv[2]+'/' ;
const html=fs.readFileSync(root+'index.html','utf8');
const data=JSON.parse(fs.readFileSync(root+'crafting-data.json','utf8'));
class Element {
  constructor(){this.children=[];this.value='';this.textContent='';}
  append(n){this.children.push(n);} replaceChildren(){this.children=[];} setAttribute(k,v){this[k]=v;}
}
const elements=new Map();
const document={getElementById(id){if(!elements.has(id))elements.set(id,new Element());return elements.get(id);},createElement(){return new Element();},createElementNS(){return new Element();}};
const context=vm.createContext({document,console});
const script=html.match(/<script>([\s\S]*)<\/script>/i)[1];
vm.runInContext(script,context,{timeout:10000});
assert(elements.get('catalog').children.length>0);
assert(elements.get('diagram').children.length===1);
elements.get('search').value='sinew';elements.get('search').oninput();
assert(elements.get('catalog').children.length>0);
elements.get('catalog').children.find(n=>n.onclick).onclick();
assert(elements.get('title').textContent.length>0);
const follow=elements.get('relations').children.find(n=>n.onclick);assert(follow);follow.onclick();
assert(elements.get('catalog').children.length>0);
elements.get('reset').onclick();assert(elements.get('search').value==='');
elements.get('siteSearch').value='farming';elements.get('siteSearch').oninput();assert(elements.get('sites').children.length>1);
assert(new Set(data.recipes.map(r=>r.id)).size===data.recipes.length);
assert(data.recipes.every(r=>r.inputs.length&&r.outputs.length&&r.file&&r.line));
for(const recipe of data.recipes)for(const resource of recipe.inputs.concat(recipe.outputs)){
  const sprite=data.resources[resource.id];assert(sprite&&sprite.type&&sprite.label);
  const bytes=fs.readFileSync(root+sprite.image);
  assert(bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])));
}
const uml=fs.readFileSync(root+'all-recipes.puml','utf8');
assert((uml.match(/<<transformation>>/g)||[]).length===data.recipes.length);
assert((uml.match(/ --> /g)||[]).length===data.recipes.reduce((n,r)=>n+r.inputs.length+r.outputs.length,0));
assert(!/<script[^>]+src=/.test(html));
console.log('PASS: initialization, recipe search/selection, resource producer/consumer navigation, reset, procedural search, record IDs, UML node/edge counts, offline assets. DOM contract only, not browser visual acceptance.');
