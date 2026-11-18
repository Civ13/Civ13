// Real clicks in real Chromium on the production bundle's circuit editor: the
// operation dropdown opens, shows its menu above the board and sends the chosen
// operation; the info button shows the component's description and ports; an
// entity input sends a mark request and shows what it holds. Fictional fixture
// data and a stand-in for the server; no BYOND process.
// Run alone: CHROMIUM_PATH=<chromium> node scripts/wiremod-browser-smoke.mjs
// (WIREMOD_SCREENSHOT_DIR=<dir> also saves the screenshots, at 2x.)
import { chromium } from 'playwright-core';
import { readFile, mkdir } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';
import { screens } from '../src/fixtures.mts';

const html = '<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="/civ13-tgui.css"></head><body><div id="root"></div><script>window.sent=[];window.Civ13Tgui={queue:[],acceptSnapshot:function(){return true},send:function(type,payload){sent.push({type,payload})},ready:function(){window.ready=true},fallback:function(){window.fallback=true}};</script><script src="/civ13-tgui.js"></script></body></html>';

export async function wiremodSmoke(browser, js, css) {
  const server = createServer((req, res) => {
    res.setHeader('Content-Type', req.url?.endsWith('.js') ? 'application/javascript' : req.url?.endsWith('.css') ? 'text/css' : 'text/html');
    res.end(req.url === '/civ13-tgui.js' ? js : req.url === '/civ13-tgui.css' ? css : html);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const fixture = screens.find(screen => screen.template === 'wiremod_circuit.tmpl');
  assert.ok(fixture, 'the circuit editor fixture is missing');
  const shots = process.env.WIREMOD_SCREENSHOT_DIR;
  if (shots) await mkdir(shots, { recursive: true });
  const page = await browser.newPage({ viewport: { width: fixture.width, height: fixture.height }, deviceScaleFactor: 2 });
  try {
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    await page.goto(`http://127.0.0.1:${server.address().port}`);
    await page.waitForFunction(() => window.ready);
    let data = structuredClone(fixture.data);
    const update = () => page.evaluate(({ title, data }) => window.receiveUpdateData(JSON.stringify({ config: { template: 'wiremod_circuit.tmpl', title, status: 2 }, data })), { title: fixture.title, data });
    const shot = async name => { if (shots) await page.screenshot({ path: `${shots}/${name}.png`, animations: 'disabled' }); };
    const sentSince = count => page.evaluate(count => window.sent.slice(count), count);
    const sentCount = () => page.evaluate(() => window.sent.length);
    await update();
    const arithmetic = page.locator('.ObjectComponent', { hasText: 'Arithmetic' });
    await arithmetic.waitFor();
    await shot('editor');

    // The operation dropdown: a real click opens it, the menu is on top and a
    // real click on an entry sends that operation for that port.
    const part = data.components.findIndex(component => component.name === 'Arithmetic');
    const operationPort = data.components[part].input_ports.findIndex(port => port.type === 'option');
    const control = arithmetic.locator('.Dropdown__control');
    assert.equal((await control.innerText()).trim(), 'Add');
    await control.click({ timeout: 5000 });
    const entry = page.locator('.Dropdown__menu--entry', { hasText: /^Multiply$/ });
    await entry.waitFor({ state: 'visible', timeout: 5000 });
    assert.deepEqual(await page.locator('.Dropdown__menu--entry').allInnerTexts(), data.components[part].input_ports[operationPort].datatype_data);
    // Nothing else is drawn over the entry: the element under its centre is the entry.
    assert.equal(await entry.evaluate(element => {
      const box = element.getBoundingClientRect();
      const top = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
      return element === top || element.contains(top);
    }), true, 'the operation menu is covered by another element');
    const menu = await page.locator('.Dropdown__menu--wrapper').evaluate(element => {
      const box = element.getBoundingClientRect(); const style = getComputedStyle(element);
      return { left: box.left, top: box.top, right: box.right, bottom: box.bottom, background: style.backgroundColor, opacity: style.opacity };
    });
    assert.ok(menu.left >= 0 && menu.top >= 0 && menu.right <= fixture.width && menu.bottom <= fixture.height, `the operation menu is off screen: ${JSON.stringify(menu)}`);
    assert.notEqual(menu.background, 'rgba(0, 0, 0, 0)', 'the operation menu has no background');
    await page.waitForFunction(() => getComputedStyle(document.querySelector('.Dropdown__menu--wrapper')).opacity === '1');
    await shot('dropdown-open');
    let before = await sentCount();
    await entry.click({ timeout: 5000 });
    // (The editor also re-sends the component's unchanged position on any mouse-up inside it.)
    assert.deepEqual((await sentSince(before)).filter(item => item.type !== 'act/set_component_coordinates'), [{ type: 'act/set_component_input', payload: { component_id: data.components[part].id, port_id: operationPort + 1, input: 'Multiply' } }]);
    await page.locator('.Dropdown__menu--entry').first().waitFor({ state: 'detached', timeout: 5000 });
    // The server applies it and sends the circuit back.
    data.components[part].input_ports[operationPort].current_data = 'Multiply';
    await update();
    await page.waitForFunction(element => element.innerText.trim() === 'Multiply', await control.elementHandle());
    await shot('dropdown-selected');

    // The info button: a real click asks for the component, and the description
    // and notices the server answers with are shown.
    before = await sentCount();
    await arithmetic.locator('.Button:has(.fa-info)').click({ timeout: 5000 });
    const [examine] = (await sentSince(before)).filter(item => item.type !== 'act/set_component_coordinates');
    assert.equal(examine?.type, 'act/set_examined_component');
    assert.equal(examine.payload.component_id, data.components[part].id);
    assert.ok(Number.isFinite(examine.payload.x) && Number.isFinite(examine.payload.y));
    const description = data.components[part].description;
    assert.match(description, /Dividing by zero/, 'the fixture component has no real description');
    // As wiremod_ui_component_notices() in code/modules/wiremod/core/circuit_ui.dm.
    const notices = [
      ...data.components[part].input_ports.map(port => ({ content: `In: ${port.name} (${port.type})`, color: port.color })),
      ...data.components[part].output_ports.map(port => ({ content: `Out: ${port.name} (${port.type})`, color: port.color })),
    ];
    assert.equal(notices.length, 4);
    data = { ...data, examined_name: data.components[part].name, examined_desc: description, examined_notices: notices, examined_rel_x: examine.payload.x, examined_rel_y: examine.payload.y };
    await update();
    const info = page.locator('.CircuitInfo__Examined');
    await info.getByText(description, { exact: true }).waitFor({ state: 'visible', timeout: 5000 });
    for (const notice of data.examined_notices) await info.getByText(notice.content, { exact: true }).waitFor({ state: 'visible', timeout: 5000 });
    const panel = await info.boundingBox();
    assert.ok(panel.x >= 0 && panel.y >= 0 && panel.x + panel.width <= fixture.width && panel.y + panel.height <= fixture.height, `the info panel is off screen: ${JSON.stringify(panel)}`);
    await shot('info-panel');
    // Clicking the board closes the panel.
    before = await sentCount();
    await page.mouse.click(fixture.width - 30, fixture.height - 30);
    assert.ok((await sentSince(before)).some(item => item.type === 'act/remove_examined_component'));
    data = { ...data, examined_name: null, examined_desc: null, examined_notices: [] };
    await update();
    await info.waitFor({ state: 'detached', timeout: 5000 });

    // An entity input: a real click asks the server to mark what the player
    // holds (the request names nothing), and the marked thing's name is shown.
    const finder = data.components.findIndex(component => component.name === 'Direction');
    const direction = page.locator('.ObjectComponent', { hasText: 'Direction' });
    const targetPort = data.components[finder].input_ports.findIndex(port => port.type === 'entity');
    const target = direction.locator('.ObjectComponent__Content .Button', { hasText: 'Target' });
    assert.equal((await target.innerText()).trim(), 'Target');
    before = await sentCount();
    await target.click({ timeout: 5000 });
    assert.deepEqual((await sentSince(before)).filter(item => item.type !== 'act/set_component_coordinates'), [{ type: 'act/set_component_input', payload: { component_id: data.components[finder].id, port_id: targetPort + 1, marked_atom: 1 } }]);
    data.components[finder].input_ports[targetPort].current_data = '<b>iron key</b>';
    await update();
    await direction.getByText('Target: <b>iron key</b>', { exact: true }).waitFor({ state: 'visible', timeout: 5000 });
    assert.equal(await direction.locator('b').count(), 0, 'an entity name was rendered as markup');
    await shot('entity-marked');

    // The editor's other popups come from the same portal: a toolbar tooltip
    // and the variable menu's type dropdown are on top and usable too.
    const onTop = locator => locator.evaluate(element => {
      const box = element.getBoundingClientRect();
      const top = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
      return element === top || element.contains(top);
    });
    const variablesButton = page.locator('.wiremod-window__buttons .Button:has(.fa-cog)');
    await variablesButton.hover();
    const tooltip = page.locator('.Tooltip', { hasText: 'Show Variables Menu' });
    await tooltip.waitFor({ state: 'visible', timeout: 5000 });
    // A tooltip ignores the pointer, so its layer is checked instead of what is under the pointer.
    assert.equal(await tooltip.evaluate(element => getComputedStyle(element.closest('.Floating')).zIndex), '100', 'the toolbar tooltip is not in the top popup layer');
    await variablesButton.click({ timeout: 5000 });
    const variables = page.locator('.Section', { hasText: 'Variable Options' });
    await variables.waitFor({ state: 'visible', timeout: 5000 });
    await variables.locator('.Dropdown__control').click({ timeout: 5000 });
    const typeEntry = page.locator('.Dropdown__menu--entry', { hasText: /^entity$/ });
    await typeEntry.waitFor({ state: 'visible', timeout: 5000 });
    assert.deepEqual(await page.locator('.Dropdown__menu--entry').allInnerTexts(), data.global_basic_types);
    assert.equal(await onTop(typeEntry), true, 'the variable type menu is covered by another element');
    await typeEntry.click({ timeout: 5000 });
    await variables.locator('input').fill('owner');
    before = await sentCount();
    await variables.locator('.Button:has(.fa-plus)').click({ timeout: 5000 });
    const added = (await sentSince(before)).find(item => item.type === 'act/add_variable');
    assert.deepEqual(added?.payload, { variable_name: 'owner', variable_datatype: 'entity', is_list: 0, is_assoc_list: 0 });

    assert.notEqual(await page.evaluate(() => window.fallback), true);
    assert.deepEqual(errors, []);
  } finally {
    await page.close();
    await new Promise(resolve => server.close(resolve));
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const root = new URL('../../UI/tgui/', import.meta.url);
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', headless: true });
  try {
    await wiremodSmoke(browser, await readFile(new URL('civ13-tgui.js', root)), await readFile(new URL('civ13-tgui.css', root)));
    console.log('PASS: circuit editor real clicks - operation dropdown opens and sends the chosen operation; info button shows the description and ports; entity input sends a mark request (production bundle, fixtures, no native bridge claim)');
  } finally { await browser.close(); }
}
