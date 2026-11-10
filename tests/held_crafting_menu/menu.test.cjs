const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('code/js/stack_crafting.js', 'utf8');
function element(attrs = {}) {
    return {value: '', style: {}, attrs, textContent: '',
        getAttribute(k) { return this.attrs[k]; }, setAttribute(k,v) { this.attrs[k] = v; }, focus() { this.focused = true; }};
}
function fixture(saved, unavailable = false) {
    const elements = Object.fromEntries(['craft-search','craft-category','craft-count','craft-empty','craft-clear','detail','quantity'].map(k => [k, element()]));
    const rows = [element({'data-search':'Wooden door Furniture', 'data-category':'2'}),
        element({'data-search':'Iron door Structures', 'data-category':'4'}),
        element({'data-search':'Planks General', 'data-category':''})];
    const details = [element({'data-craft-details':'detail'})];
    const batches = [element({'data-craft-quantity':'quantity'})];
    const store = {'held-crafting:stack1': saved && JSON.stringify(saved)};
    const window = {location: {href: ''}, sessionStorage: {
        getItem(k) { if (unavailable) throw Error('storage unavailable'); return store[k] || null; },
        setItem(k,v) { if (unavailable) throw Error('storage unavailable'); store[k] = v; }
    }};
    const document = {body: element({'data-stack':'stack1'}), getElementById: k => elements[k],
        querySelectorAll: q => q === '.craft-row' ? rows : q === '[data-craft-details]' ? details : batches};
    vm.runInNewContext(source, {window, document});
    return {elements, rows, details, batches, window, store};
}
let f = fixture();
const e = f.elements;
assert.equal(e['craft-count'].textContent, ' 3 of 3 recipes');
e['craft-category'].value = '2'; e['craft-category'].onchange();
assert.equal(f.rows[1].style.display, 'none');
e['craft-search'].value = 'DOOR'; e['craft-search'].oninput();
assert.equal(e['craft-category'].value, '');
assert.equal(f.rows[0].style.display, ''); assert.equal(f.rows[1].style.display, '');
assert.equal(f.rows[2].style.display, 'none');
e['craft-search'].value = 'wooden furniture'; e['craft-search'].oninput();
assert.equal(e['craft-count'].textContent, ' 1 of 3 recipes');
e['craft-search'].value = '<script>'; e['craft-search'].oninput();
assert.equal(e['craft-empty'].style.display, '');
assert.equal(f.window.location.href, '');
e['craft-search'].onkeydown({keyCode:27});
assert.equal(e['craft-count'].textContent, ' 3 of 3 recipes');
assert.equal(e['craft-search'].onkeydown({keyCode:13, preventDefault(){}}), false);
assert.equal(f.window.location.href, '');
e['craft-search'].value = 'plank'; e['craft-search'].oninput();
const refreshed = fixture(JSON.parse(f.store['held-crafting:stack1']));
assert.equal(refreshed.elements['craft-search'].value, 'plank');
assert.equal(refreshed.elements['craft-count'].textContent, ' 1 of 3 recipes');
e['craft-clear'].onclick();
assert.equal(e['craft-count'].textContent, ' 3 of 3 recipes');
assert.equal(e['craft-search'].focused, true);
assert.equal(e.detail.style.display, 'none');
f.details[0].onclick(); assert.equal(e.detail.style.display, '');
f.details[0].onclick(); assert.equal(e.detail.style.display, 'none');
e.quantity.value = 'byond://?src=stack1;sublist=4;make=17;multiplier=10';
assert.equal(f.window.location.href, '');
f.batches[0].onclick(); assert.equal(f.window.location.href, e.quantity.value);
assert.equal(fixture(null, true).elements['craft-count'].textContent, ' 3 of 3 recipes');
console.log('PASS: cross-category search, categories, multiword/case matching, no matches, escape/clear/enter, refresh, details, explicit batch action, unavailable storage');
