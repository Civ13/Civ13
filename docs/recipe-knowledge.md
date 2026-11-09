# Personal recipe manuals (issue #4239, phase 1)

This feature is inactive by default. A Persistence map may opt in with the
`recipe_books` configuration flag; no shipped map is enabled by this change.
Round maps retain their faction/era rules. The flag is not saved as mutable map
metadata. To enable it in an already running world, the operator integration
must call `activate_recipe_books()` instead of assigning the flag directly.
Activation itself is outside this PR's authorization.

With the flag enabled, non-basic crafting needs both faction/era research and
personal knowledge of the node. The explicit basic recipes remain open. Read a
node manual for one minute to learn it. Reading leaves the book intact and
repeated reading does not duplicate knowledge. Books cannot bypass research.
The book's subject is a text ID, not a reference to a research datum.

Existing saved bodies receive one grant of the nodes unlocked by their restored
faction and era, after world restoration. The marker and list are saved on each
body. New bodies created with this feature enabled start empty, including after
save/reload. Death clears personal knowledge; a fresh body does not inherit it.
AI-controlled Nomads are exempt from the personal gate, not the research ceiling.
NPC trader shops are not player crafting actions.

Research completion makes one reusable manual at a faction bench, falling back
to a living faction member if there is no bench. One-copy versus per-member
balance remains a design decision; this draft proposes one copy. Starter stock,
copying, printing, teaching and compendiums follow in phase 2, menu hints in phase 3.

Region travel uses version 2 for knowledge or manuals. Known IDs survive travel
regardless of the destination research ceiling, which still controls crafting.
Old version-1 arrivals remain accepted; unsupported versions and unknown node
IDs are refused rather than silently lost. Knowledge-carrying travel requires
upgraded peers. The existing payload size and item count limits still apply.

## Verification

`tests/recipe_knowledge/test_contract.py` checks source wiring offline and is
registered in the baseline. `tests/recipe_knowledge/run.py --byond-bin <bin>`
compiles the production game with isolated startup and an 8x8 offline fixture.
Its native cases cover real world-save/reload, new/dead bodies, legacy migration,
repeat learning/reading, invalid IDs and the research ceiling. The fixture
adapts human construction/physiology and does not establish connected-client
reading cancellation or live-server migration acceptance. It runs without
trusted mode, with no port and only disposable fixture files.
