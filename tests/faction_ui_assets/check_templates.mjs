// Offline execution of the repository's actual template engine/helpers.
// The data/bootstrap boundary is injected; this is not DOM/browser acceptance.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const ready = [];
const $ = () => ({data: key => key === 'urlParameters' ? {src: '[0xfixture]'} : null,
                 ready: callback => ready.push(callback)});
$.isFunction = value => typeof value === 'function';
$.ajaxSetup = () => {};
const context = vm.createContext({console, document: {}, window: {}, jQuery: $, $, alert: text => {throw new Error(text);}});
for (const file of ['UI/js/libraries/doT.js', 'UI/js/nano_template.js',
                    'UI/js/nano_utility.js', 'UI/js/nano_base_helpers.js']) {
    vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8'), context, {filename: file});
}
vm.runInContext('NanoUtility.init(); NanoBaseHelpers.addHelpers();', context);
for (const name of ['layout_basic', 'faction_creation', 'faction_symbol']) {
    context.NanoTemplate.addTemplate(name, fs.readFileSync(path.join(root, 'UI/templates', name + '.tmpl'), 'utf8'));
}
const data = {name: '', motto: '', flavour: '', grid: Array(1024).fill('#FFFFFF'), tool: 'paint', color: '#000000'};
for (const name of ['faction_creation', 'faction_symbol']) {
    const html = context.NanoTemplate.parse(name, {data, config: {status: 2}});
    assert.equal((html.match(/class='fs-cell'/g) || []).length, 1024);
    assert.ok(html.includes("data-x='1' data-y='1'"));
    assert.ok(html.includes("data-x='32' data-y='32'"));
    assert.ok(!html.includes('{{'));
    if (name === 'faction_creation') {
        assert.ok(html.includes('Found a new faction'));
        assert.ok(html.includes('(no name chosen yet)'));
        assert.ok(html.includes('src=[0xfixture];found=1'));
        assert.ok(html.includes('src=[0xfixture];set_name=1'));
    }
}
assert.ok(context.NanoTemplate.parse('layout_basic', {data, config: {}}).includes("id='uiContent'"));
assert.equal(ready.length, 1, 'offline seam must not run document/browser bootstrap');
console.log('PASS actual doT/NanoTemplate/helper execution: faction creation, symbol editor, basic layout; DOM/browser UNRUN');
