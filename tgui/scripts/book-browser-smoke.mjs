// Real production Chromium. Local fictional data; no native bridge/ink claim.
import { chromium } from 'playwright-core';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import assert from 'node:assert/strict';
const fixture=JSON.parse(await readFile(new URL('../../tests/tgui/fixtures/book-page.json',import.meta.url),'utf8'));
const js=await readFile(new URL('../../UI/tgui/civ13-tgui.js',import.meta.url));
const css=await readFile(new URL('../../UI/tgui/civ13-tgui.css',import.meta.url));
const html='<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/app.css"></head><body><div id="root"></div><script>window.sent=[];window.fallbacks=0;window.Civ13Tgui={queue:[],acceptSnapshot:()=>true,send:(...args)=>sent.push(args),ready:()=>window.ready=true,fallback:()=>window.fallbacks++};</script><script src="/app.js"></script></body></html>';
const server=createServer((req,res)=>{res.setHeader('Content-Type',req.url==='/app.js'?'application/javascript':req.url==='/app.css'?'text/css':'text/html');res.end(req.url==='/app.js'?js:req.url==='/app.css'?css:html);});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
let browser;
try {
 browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true});
 const page=await browser.newPage({viewport:{width:625,height:650}});
 const fresh=async(data={runs:fixture.runs},media)=>{
  await page.emulateMedia({forcedColors:media||'none',media:'screen'});
  await page.goto(`http://127.0.0.1:${server.address().port}`);await page.waitForFunction(()=>window.ready);
  await page.evaluate(data=>window.receiveUpdateData(JSON.stringify({config:{template:'book_reader.tmpl',title:'Book fixture',status:1},data})),data);
 };
 await fresh();await page.locator('.book-page').waitFor();
 const computed=await page.locator('.book-page').evaluate(p=>({bg:getComputedStyle(p).backgroundColor,ink:getComputedStyle(p).color,runs:[...p.children].map(e=>({ink:getComputedStyle(e).color,fill:getComputedStyle(e).webkitTextFillColor,font:getComputedStyle(e).fontFamily,italic:getComputedStyle(e).fontStyle}))}));
 assert.equal(computed.bg,'rgb(255, 255, 255)');assert.equal(computed.ink,'rgb(0, 0, 0)');
 assert.equal(computed.runs[1].ink,computed.bg);assert.equal(computed.runs[2].ink,computed.bg);assert.equal(computed.runs[2].fill,computed.bg);
 assert.match(computed.runs[1].font,/Verdana/);assert.match(computed.runs[2].font,/Times New Roman/);assert.equal(computed.runs[2].italic,'italic');
 assert.equal(await page.locator('.book-page').textContent(),'Default Hidden SignatureVisible & safe');
 assert.equal(await page.locator('.book-page [aria-label],.book-page [aria-describedby],.book-page [title],.book-page [hidden],.book-page button,.book-page a,.book-page input,.book-page textarea').count(),0);
 const ax=await page.locator('.book-page').ariaSnapshot();assert.equal((ax.match(/Hidden/g)||[]).length,1);assert.equal((ax.match(/Signature/g)||[]).length,1);
 // Existing ordinary text remains selectable; no app copy/reveal functionality.
 const selected=await page.locator('.book-page').evaluate(p=>{const range=document.createRange();range.selectNodeContents(p);const s=getSelection();s.removeAllRanges();s.addRange(range);return s.toString();});
 assert.match(selected,/Hidden Signature/);assert.equal(await page.evaluate(()=>window.sent.length),0);assert.equal(await page.evaluate(()=>window.fallbacks),0);
 for(const cause of ['ancestor-opacity','ancestor-filter','run-override','horizontal-overflow','print','forced-colors','invalid-metadata','oversized']){
  if(cause==='invalid-metadata')await fresh({runs:[...fixture.runs,{...fixture.runs[0],title:'Hidden'}]});
  else if(cause==='oversized')await fresh({runs:[{...fixture.runs[0],text:'A'.repeat(65537)}]});
  else if(cause==='forced-colors')await fresh(undefined,'active');
  else {
   await fresh();await page.locator('.book-page').waitFor();
   if(cause==='ancestor-opacity')await page.locator('.civ13-app').evaluate(e=>e.style.opacity='.9');
   if(cause==='ancestor-filter')await page.locator('.civ13-app').evaluate(e=>e.style.filter='invert(1)');
   if(cause==='run-override')await page.locator('[data-book-run="1"]').evaluate(e=>e.style.color='black');
   if(cause==='horizontal-overflow')await page.locator('.book-page').evaluate(e=>{e.style.width='1px';e.style.whiteSpace='nowrap';});
   if(cause==='print')await page.emulateMedia({media:'print'});
  }
  await page.waitForFunction(()=>window.fallbacks===1,undefined,{timeout:5000}).catch(error=>{throw new Error(cause+': '+error.message);});assert.equal(await page.locator('.book-page').count(),0,cause);
  assert.equal(await page.evaluate(()=>window.sent.length),0,cause);
 }
 // Independent complete legacy snapshot fixture: no partial parser repair.
 await page.setContent('<HTML><HEAD><TITLE>Book fixture</TITLE></HEAD><BODY>'+fixture.html+'</BODY></HTML>');
 const classic=await page.locator('body').evaluate(p=>({bg:getComputedStyle(p).backgroundColor,color:getComputedStyle(p).color,white:[...p.querySelectorAll('font')].map(e=>getComputedStyle(e).color)}));
 assert.equal(classic.white[0],'rgb(255, 255, 255)');assert.equal(classic.white[1],'rgb(255, 255, 255)');
 console.log('PASS: Book production Chromium white-on-white/font/signature inheritance, ordinary accessible/selectable text without extra summaries or controls, eight whole-view rejection/fallback cases, complete classic fixture; native bridge/ink/cache/Unicode/lifecycle untested');
}finally{await browser?.close();await new Promise(resolve=>server.close(resolve));}
