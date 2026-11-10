# Held-material crafting menu

`python3 -m unittest discover -s tests/held_crafting_menu -v`

The Python suite checks source action identities, visibility/escaping contracts
and unchanged authoritative Topic dispatch. It runs `menu.test.cjs` with Node;
the production ES5 script executes against a small DOM/storage adapter. Tests
cover cross-category search, case and multiword matching, category browsing,
no results, Escape/Clear, non-crafting Enter, refresh state, repeated detail
toggles, explicit batch submission and unavailable session storage.

The menu renders the already-authorized material catalog. Search does not add
recipes, bypass manual/research checks, or turn tool interactions (such as
sawing logs into planks) into new crafting routes. Original root/category
indices are retained on single and batch links. Tool hints start visible if
JavaScript is unavailable; one-item crafting still works via ordinary links.

Native acceptance remains separate: Dream Seeker embedded-browser rendering,
focus/movement while typing, actual Topic navigation and stock refresh, manual
changes, stale windows, interrupted crafts and simultaneous stack changes.
The CI baseline suite `held_crafting_menu` selects these offline checks for
menu/script changes; the shared stack file retains all-suite selection.
