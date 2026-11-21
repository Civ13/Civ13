// Run: node tests/razor_grooming/test_preview_ui.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function select(sources) {
    return {selectedIndex: 0, options: sources.map((src) => ({
        getAttribute: (name) => src && src + '-' + name,
    }))};
}
const attributes = {'data-ref': '[0x42]', 'data-nonce': '0123456789abcdef0123456789abcdef'};
const nodes = {
    'grooming-preview': {getAttribute: (key) => attributes[key]},
    'groom-hair': select(['current-hair', 'second-hair']),
    'groom-beard': select(['current-beard', '']),
    'groom-apply': {},
};
for (const id of ['scalp-front', 'scalp-side', 'beard-front', 'beard-side']) {
    nodes[id] = {style: {}};
}
const window = {location: {href: 'initial'}};
const document = {getElementById: (id) => nodes[id]};
const script = path.join(__dirname, '../../UI/js/grooming_preview.js');
vm.runInNewContext(fs.readFileSync(script, 'utf8'), {document, window});
window.onload();
assert.equal(nodes['groom-apply'].disabled, true);
nodes['groom-apply'].onclick();
assert.equal(window.location.href, 'initial');
assert.equal(nodes['scalp-front'].src, 'current-hair-data-front');
assert.equal(nodes['scalp-side'].src, 'current-hair-data-side');
nodes['groom-hair'].selectedIndex = 1;
nodes['groom-hair'].onchange();
assert.equal(nodes['scalp-front'].src, 'second-hair-data-front');
assert.equal(nodes['scalp-side'].src, 'second-hair-data-side');
assert.equal(nodes['beard-front'].src, 'current-beard-data-front');
assert.equal(window.location.href, 'initial');
nodes['groom-beard'].selectedIndex = 1;
nodes['groom-beard'].onchange();
assert.equal(nodes['beard-side'].style.display, 'none');
assert.equal(window.location.href, 'initial');
const originalRef = attributes['data-ref'];
attributes['data-ref'] = 'invalid reference';
nodes['groom-apply'].onclick();
assert.equal(window.location.href, 'initial');
attributes['data-ref'] = originalRef;
const originalNonce = attributes['data-nonce'];
attributes['data-nonce'] = 'value;separator';
nodes['groom-apply'].onclick();
assert.equal(window.location.href, 'initial');
attributes['data-nonce'] = originalNonce;
nodes['groom-apply'].onclick();
assert.equal(window.location.href, 'byond://?src=[0x42];groom=apply;nonce=0123456789abcdef0123456789abcdef;hair=2;beard=2');
assert.equal(nodes['groom-apply'].disabled, true);
console.log('Grooming dropdown, preview layers, and Apply: passed');
