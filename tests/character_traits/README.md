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

## Zero-point Random button

`test_random.py` adds deterministic specification cases and production-source
contracts for the Random link. The new selection replaces the entire old set
only after catalog/conflict/budget validation and an exact zero-total check.
The owner/session and latest rendered revision must match; a consumed link
cannot replay. Generation has no yielding dialog. Invalid results, exhausted
searches and rejected links preserve the old trait value without an explicit
save in the Random handler. Successful choices use the existing preference
save path and setup refresh, including preview and total recomputation.

The sampler first considers all eligible zero-cost singletons, then makes 64
trials. Each trial shuffles the eligible catalog with Fisher-Yates, independently
skips about half its entries, and accepts additions through the shared validator
with budget checking temporarily disabled. This allows positive intermediate
totals to balance later. Every nonempty zero-total prefix enters a reservoir;
the final result is validated again with the ordinary budget rule. The injected
`/datum/trait_random_source/next_integer(upper)` seam returns integers from 1 through
`upper` for deterministic future DM fixtures. Production uses `rand(1, upper)`.

Sampling is deliberately **not uniform over valid trait sets**: greedy conflict
resolution, prefix ordering, repeated observations and the zero-cost seed pass
all bias the distribution. Repeated clicks can produce the same set. No point
costs, exclusions, catalog entries or existing validation rules are changed.
Legacy malformed choices may be explicitly replaced by a successful Random
click; a failed click never clears them.

The catalog is capped at 64 entries (currently 24). At most 64 singleton checks,
4096 trial candidate checks, 4032 shuffle draws and one final validation occur
per call. An oversized catalog fails without truncation. If no nonempty valid
zero-total combination is found within that work bound, the handler explains
that choices were kept and allows a fresh click. This is not proof that no
solution exists; every eligible zero-cost singleton is guaranteed consideration.
No empty fallback is committed. A catalog size increase past 64 needs an explicit
bound review.

The suite runs 200 seeded selections from the production catalog, tests exact
zero, variation, duplicate prevention, asymmetric conflicts, self-exclusion,
disabled traits, zero-cost fallback, positive intermediate totals, impossible
and exhausted searches, the catalog bound, repeated/stale/malformed links,
ownership, and unchanged state on failure. Mutation controls remove critical
production guards and must be detected. The Python sampler is a specification
model, **not execution of the DM implementation**; source contracts tie its
intended algorithm and commit guards to production. Native compilation, actual
BYOND RNG/list behavior, client refresh and real preference serialization remain
separate verification work.

Normal CI registers both `test_foundations.py` and `test_random.py` in the
reviewed `character_traits` offline baseline suite. Changes under this test
directory select that suite; its six shared production inputs keep the existing
conservative all-suite fallback. The existing required aggregate rejects a failed
or skipped selected suite. `tests/test_ci_baseline.py` runs the actual registered
child in temporary offline storage, then removes the exact-zero commit guard in
that copied source and verifies failure propagates through baseline and aggregate.
This registration adds no native fixture, workflow permission or admission gate.
