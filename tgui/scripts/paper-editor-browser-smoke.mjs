// Reuse the existing owned Chromium; no BYOND, new server or native bridge.
// Each synthetic context is offline and all requests are aborted.
import assert from 'node:assert/strict';
export async function paperEditorSmoke(browser, js, css) {
  const context = await browser.newContext({ viewport: { width: 900, height: 850 }, offline: true });
  await context.route('**/*', route => route.abort());
  const errors = [];
  const load = async () => {
    const page = await context.newPage();
    page.setDefaultTimeout(5000); page.on('pageerror', error => errors.push(error.message));
    await page.setContent('<!doctype html><html><head><meta charset="utf-8"></head><body><div id="root"></div></body></html>');
    await page.addStyleTag({ content: css.toString() });
    await page.evaluate(() => {
      window.sent = []; window.fallback = false;
      window.Civ13Tgui = { queue: [], acceptSnapshot: () => true,
        send: (type,payload) => window.sent.push({type,payload}), ready: () => { window.ready=true; },
        fallback: () => { window.fallback=true; } };
    });
    await page.addScriptTag({ content: js.toString() }); await page.waitForFunction(() => window.ready);
    return page;
  };
  const EN='civ13:english:v1';
  const data = () => ({ lease:'a'.repeat(32),document_id:null,revision:0,free_space:3072,
    languages:[{id:EN,name:'English'}],default_language_id:EN,
    view:{legacy_name:'Synthetic paper',legacy_body_html:'',sections:[]},
    draft_ink:'white',draft_tool:'pen',draft_signature:'Fixture Name',response_serial:0,result:'ready' });
  const update = async (page,value) => page.evaluate(value => window.receiveUpdateData(JSON.stringify({
    config:{template:'paper_editor.tmpl',title:'Paper fixture',status:2},data:value })),value);
  try {
    const page=await load();let current=data();await update(page,current);
    await page.getByLabel('Writing text').waitFor();assert.equal(await page.evaluate(()=>window.fallback),false);
    // An oversized escaped draft remains local; it is neither truncated nor
    // replayed, and preview overflow cannot discard the unsent text.
    await page.getByLabel('Writing text').fill('\\'.repeat(3072));
    await page.getByRole('button',{name:'Write',exact:true}).click();
    await page.getByText('This text cannot fit in one submission.',{exact:true}).waitFor();
    assert.equal(await page.evaluate(()=>window.sent.length),0);
    assert.equal(await page.evaluate(()=>window.fallback),false);
    const writing='Synthetic <paper> & \u65e5\u672c\u8a9e \ud83d\udea2';
    await page.getByLabel('Writing text').fill(writing);
    await page.getByRole('button',{name:'Write',exact:true}).click();
    await page.waitForFunction(()=>window.sent.length===1);
    const sent=await page.evaluate(()=>window.sent[0]);
    assert.equal(sent.type,'act/paper_edit');
    assert.deepEqual(JSON.parse(sent.payload.paper_edit),{operation:'append',lease:'a'.repeat(32),document_id:null,revision:0,language_id:EN,kind:'body',value:writing});
    current={...current,lease:'c'.repeat(32),document_id:'b'.repeat(32),revision:1,response_serial:1,result:'saved',
      view:{...current.view,revision:1,legacy_policy:'legacy_unclassified',sections:[
        {id:'section-1',kind:'body',language_id:EN,text:writing,ink:'white',tool:'pen'}]}};
    await update(page,current);await page.getByText('Writing saved.',{exact:true}).waitFor();
    assert.equal(await page.getByLabel('Writing text').inputValue(),'');
    const paper=page.locator('article').first(), run=paper.locator('[data-book-run]').nth(0);
    assert.equal(await paper.textContent(),writing);assert.equal(await paper.locator('paper,img,script,button,[title],[aria-label],[hidden]').count(),0);
    assert.equal(await paper.evaluate(e=>getComputedStyle(e).backgroundColor),'rgb(255, 255, 255)');
    assert.equal(await run.evaluate(e=>getComputedStyle(e).color),'rgb(255, 255, 255)');
    await page.setViewportSize({width:380,height:700});
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
    // Older pencode HTML and crayon writing render as inert styled text in the
    // real Chromium page checks; the editor stays usable and does not fall back.
    const legacyHtml='<font face="Verdana" color=blue><b>Orders</b><BR>March north<img src=x onerror="window.pwned=1"><script>window.pwned=1</script>'
      +'<table><tr><td>a</td><td>b</td></tr></table><span class="paper_field"></span></font><font face="Comic Sans MS" color=#ff0000><b>crayon</b></font>';
    const legacy=await load();
    await update(legacy,{...data(),draft_tool:'crayon',draft_ink:'#ff0000',view:{legacy_name:'Synthetic paper',legacy_body_html:legacyHtml,sections:[
      {id:'section-1',kind:'body',language_id:EN,text:'Wax [b]bold[/b]\n'+'W'.repeat(400),ink:'#ff0000',tool:'crayon'}]},document_id:'b'.repeat(32),revision:1});
    await legacy.getByLabel('Writing text').waitFor();
    const legacyPage=legacy.locator('article').first();
    assert.equal(await legacy.evaluate(()=>window.fallback),false);
    assert.equal(await legacy.evaluate(()=>window.pwned),undefined);
    assert.equal(await legacyPage.locator('img,script,table,font').count(),0);
    assert.match(await legacyPage.textContent(),/^OrdersMarch north\[stamp\]a b crayonWax boldW+$/);
    const orders=legacyPage.locator('[data-book-run]').first();
    assert.equal(await orders.evaluate(e=>getComputedStyle(e).color),'rgb(0, 0, 255)');
    assert.equal(await orders.evaluate(e=>getComputedStyle(e).fontWeight),'700');
    const wax=legacyPage.getByText('crayon',{exact:true});
    assert.equal(await wax.evaluate(e=>getComputedStyle(e).fontFamily.split(',')[0].replaceAll('"','')),'Comic Sans MS');
    assert.equal(await legacy.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
    await legacy.getByLabel('Writing text').fill('More [i]wax[/i]');
    await legacy.getByRole('button',{name:'Write',exact:true}).click();
    await legacy.waitForFunction(()=>window.sent.length===1);
    assert.equal(JSON.parse((await legacy.evaluate(()=>window.sent[0])).payload.paper_edit).value,'More [i]wax[/i]');
    const invalid=await load();await update(invalid,{...data(),view:{legacy_name:'Synthetic paper',legacy_body_html:'UNSUPPORTED_PARTIAL'+'x'.repeat(65536),sections:[]}});
    await invalid.getByText('Switching to classic interface...',{exact:true}).waitFor();
    assert.equal(await invalid.evaluate(()=>window.fallback),true);
    assert.equal((await invalid.locator('body').textContent()).includes('UNSUPPORTED_PARTIAL'),false);
    assert.equal(await invalid.locator('textarea').count(),0);
    assert.deepEqual(errors,[]);
    console.log('PASS: Paper production form, Unicode/inert text, legacy pencode and crayon rendering, bounded append, no replay/truncation, white ink, narrow layout and oversize fallback; substituted transport, no native acceptance');
  } finally { await context.close(); }
}
