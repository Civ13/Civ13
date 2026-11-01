// Unsupported JSDOM CSS environment must request whole-view fallback.
import { JSDOM, VirtualConsole } from 'jsdom';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const dom=new JSDOM('<!doctype html><body data-ref="[0x123]" data-window="book[0x456]" data-generation="2"><div id="root"></div><p id="tgui-loading"><a id="tgui-legacy">Classic</a></p></body>',{runScripts:'outside-only',url:'http://127.0.0.1/',virtualConsole:new VirtualConsole()});
const w=dom.window,messages=[];
Object.defineProperty(w.navigator,'userAgent',{value:'Chrome/130.0 (JSDOM fixture)'});
w.cef_to_byond=url=>messages.push(new URL(url).searchParams.get('type'));
try{
 w.eval(readFileSync(new URL('../../UI/tgui/civ13-tgui-bootstrap.js',import.meta.url),'utf8'));
 w.eval(readFileSync(new URL('../../UI/tgui/civ13-tgui.js',import.meta.url),'utf8'));
 await new Promise(resolve=>setTimeout(resolve,40));
 const fixture=JSON.parse(readFileSync(new URL('../../tests/tgui/fixtures/book-page.json',import.meta.url),'utf8'));
 w.receiveUpdateData(JSON.stringify({config:{template:'book_reader.tmpl',title:'Book fixture',status:1,ref:'[0x123]',window:'book[0x456]',generation:2},data:{runs:fixture.runs}}));
 await new Promise(resolve=>setTimeout(resolve,80));
 assert.equal(messages.filter(type=>type==='fallback').length,1);assert.equal(w.document.querySelector('.book-page'),null);
 assert.ok(!w.document.body.textContent.includes('Hidden'));assert.ok(!messages.some(type=>type.startsWith('act/')));
 console.log('PASS: Book actual production bootstrap/bundle requests one fallback and removes complete body in unsupported JSDOM; not positive visual or native acceptance');
}finally{w.close();}
