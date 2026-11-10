/* Held-material recipe browsing only. Crafting remains an explicit Topic action.
 * ES5 syntax for Dream Seeker's embedded browser. No external dependencies. */
(function () {
    'use strict';
    var search = document.getElementById('craft-search');
    var category = document.getElementById('craft-category');
    if (!search || !category) return;
    var rows = document.querySelectorAll('.craft-row');
    var count = document.getElementById('craft-count');
    var empty = document.getElementById('craft-empty');
    var key = 'held-crafting:' + document.body.getAttribute('data-stack');
    var entries = [];
    var i;
    for (i = 0; i < rows.length; i++) {
        entries.push({node: rows[i], text: rows[i].getAttribute('data-search').toLowerCase(),
            category: rows[i].getAttribute('data-category')});
    }
    // Best effort per-window state across stock refreshes. Never stored on the
    // shared material datum; unavailable storage must not disable the menu.
    try {
        var saved = JSON.parse(window.sessionStorage.getItem(key));
        if (saved && typeof saved.query === 'string') search.value = saved.query.slice(0, 64);
        if (saved && typeof saved.category === 'string') category.value = saved.category;
    } catch (ignore) {}
    function filter() {
        var query = search.value.slice(0, 64).toLowerCase().replace(/^\s+|\s+$/g, '');
        var words = query ? query.split(/\s+/) : [];
        var visible = 0;
        // A search always spans categories, including when entered from a tab.
        if (query) category.value = '';
        for (var n = 0; n < entries.length; n++) {
            var entry = entries[n];
            var matches = !category.value || entry.category === category.value;
            for (var w = 0; w < words.length && matches; w++) {
                matches = entry.text.indexOf(words[w]) !== -1;
            }
            entry.node.style.display = matches ? '' : 'none';
            if (matches) visible++;
        }
        count.textContent = ' ' + visible + ' of ' + entries.length + ' recipes';
        empty.style.display = visible ? 'none' : '';
        try {
            window.sessionStorage.setItem(key, JSON.stringify({query: search.value.slice(0, 64), category: category.value}));
        } catch (ignore) {}
    }
    search.oninput = filter;
    search.onkeydown = function (event) {
        event = event || window.event;
        if (event.keyCode === 27) {
            search.value = '';
            filter();
        }
        // Enter must never craft an arbitrary first match.
        if (event.keyCode === 13) {
            if (event.preventDefault) event.preventDefault();
            return false;
        }
    };
    category.onchange = function () {
        search.value = '';
        filter();
    };
    document.getElementById('craft-clear').onclick = function () {
        search.value = '';
        category.value = '';
        filter();
        search.focus();
    };
    var details = document.querySelectorAll('[data-craft-details]');
    for (i = 0; i < details.length; i++) {
        var panel = document.getElementById(details[i].getAttribute('data-craft-details'));
        panel.style.display = 'none';
        details[i].setAttribute('aria-expanded', 'false');
        details[i].onclick = function () {
            var target = document.getElementById(this.getAttribute('data-craft-details'));
            var open = target.style.display === 'none';
            target.style.display = open ? '' : 'none';
            this.setAttribute('aria-expanded', open ? 'true' : 'false');
        };
    }
    var batches = document.querySelectorAll('[data-craft-quantity]');
    for (i = 0; i < batches.length; i++) {
        batches[i].onclick = function () {
            var select = document.getElementById(this.getAttribute('data-craft-quantity'));
            // Values are server-produced links retaining original sublist/index.
            // Changing a quantity alone never submits a craft action.
            if (select && select.value) window.location.href = select.value;
        };
    }
    filter();
}());
