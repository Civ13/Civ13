# Character trait foundation checks

Run the cloud-safe offline checks:

```sh
python -m unittest discover -s tests/character_traits -v
python -m unittest discover -s tests/lobby_join -v
python -m unittest discover -s tests/save_movement -p test_character_return.py -v
python -m unittest discover -s tests/zone_persistence -p test_contract.py -v
```

The trait suite parses the production catalog, checks every declared exclusion in
both orders, and checks source contracts for non-mutating validation, editable
budgets, unknown/duplicate legacy entries, exact removal, delayed prompt
revalidation, empty/duplicate preference serialization, spawn list ownership,
Baldness initialization, and social self-exclusion. An independent Python model
exercises table cases; it is not a DM interpreter. Mutation controls distinguish
missing validation guards and the old social self-counting expression.

Existing lobby tests cover all admission points and preserve the unrelated
historical join body through exact inverse replacements, not a refreshed digest.
Character-return checks cover the preservation boundary: saved-body reclaim stays
before validation of choices for a new character. Climate assignment and crafting
stat modifiers, recipes and outputs are unchanged.

Invalid saved choices are retained and explained, not silently repaired. Players
remove individual legacy entries explicitly. A malformed non-list value has a
separate confirmed Clear action. Adding a trait may temporarily exceed budget,
but contradictory/unknown/duplicate choices are refused; readiness and spawning
require all checks, including budget. Baldness now costs zero, so a formerly
balanced build using its point refund can require the player's correction before
creating a new body. Existing saved bodies are not revalidated or rewritten.

## Evidence boundary

These checks are offline source/specification evidence only. Full DM compilation,
native fixtures, connected-client dialogs, real preference-file roundtrips,
world-save reloads, live gameplay and balance are not verified by this suite.
Before release, separately exercise: cancel/back/repeated Add and Remove; changed
preferences while dialogs are open; legacy duplicate/unknown entries across a
real save/load; roundstart refusal without losing the lobby; regional spawn
without rewriting preferences; male/female Baldness; and alone/near living/near
dead social mood in hunger-enabled and disabled modes. No native process is
started by these checks.
