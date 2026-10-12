import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createReference, parseReference, referenceUrl } from './dm-reference.mjs';
const html = '<script>bad()</script><a name=/list/proc/Cut><h2>Cut</h2><p>Remove &lt;entries&gt;.</p><pre>list.Cut(1, 2)</pre><a name="/proc/sleep"><p>Wait</p>';
test('official topics, escaped examples, pagination, ranking and cached provenance', async () => {
  let calls = 0;
  const read = createReference(async (url, options) => {
    assert.equal(url, referenceUrl); assert.equal(options.redirect,'error'); assert.equal(options.credentials,'omit'); calls++;
    return new Response(html, { headers: { 'content-type': 'text/html' } });
  });
  const search = await read({query:'Cut',limit:1}); assert.equal(search.matches[0].topic,'/list/proc/Cut');
  const entry = await read({topic:search.matches[0].topic,length:10}); assert.equal(entry.truncated,true);
  const full = await read({topic:'/list/proc/Cut'}); assert.match(full.text,/Remove <entries>/); assert.doesNotMatch(full.text,/bad\(\)|Wait/);
  assert.match(full.sha256,/^[a-f0-9]{64}$/); assert.equal(calls,1);
  await assert.rejects(read({topic:'https://evil.invalid/'}),/Unknown topic/);
  assert.throws(() => parseReference('<html>error page</html>'),/no recognizable/);
});

test('streaming size limit, concurrent fetch bound and recovery after cancellation', async () => {
  const oversized = new ReadableStream({ start(controller) { controller.enqueue(new Uint8Array(8 * 1024 * 1024 + 1)); controller.close(); } });
  await assert.rejects(createReference(async()=>new Response(oversized,{headers:{'content-type':'text/html'}}))({query:'Cut'}),/size limit/);
  let calls = 0;
  const read = createReference(async (_,options) => {
    if (++calls > 1) return new Response(html,{headers:{'content-type':'text/html'}});
    return new Promise((resolve,reject)=>options.signal.addEventListener('abort',()=>reject(Error('aborted'))));
  });
  const controller = new AbortController();
  const pending = read({query:'Cut'},controller.signal);
  await assert.rejects(read({query:'Cut'}),/already active/);
  controller.abort(); await assert.rejects(pending,/aborted/);
  assert.equal((await read({query:'Cut'})).matches[0].topic,'/list/proc/Cut');
  assert.equal(calls,2);
});
test('HTTP, content type, oversize, abort and duplicate topics fail closed', async () => {
  for (const response of [new Response('missing',{status:404}),new Response(html),new Response(html,{headers:{'content-type':'text/html','content-length':'9000000'}})]) {
    let fetchSignal;
    await assert.rejects(createReference(async(_,options)=>{fetchSignal=options.signal; return response;})({query:'Cut'}));
    assert.equal(fetchSignal.aborted,true);
  }
  const controller = new AbortController(); controller.abort();
  await assert.rejects(createReference(async()=>{throw Error('must not fetch');})({query:'Cut'},controller.signal),/Cancelled/);
  assert.throws(()=>parseReference(html+'<a name=/proc/sleep>duplicate'),/Duplicate/);
  const pending = new AbortController();
  const read = createReference(async (_,options) => new Promise((resolve,reject)=>options.signal.addEventListener('abort',()=>reject(Error('aborted')))));
  const request = read({query:'Cut'},pending.signal); pending.abort(); await assert.rejects(request,/aborted/);
});
