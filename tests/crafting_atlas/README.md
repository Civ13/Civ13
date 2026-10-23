# Crafting atlas verification

Use pinned BYOND 516.1681. `run.py --byond-bin <bin>` compiles and executes
production reference rendering in temporary storage with startup and ports
disabled. No clients or gameplay constructors are used. `--full-catalog` also
checks all generated records and real sawmill/grain processing views.
It also checks the tanning rack's research/conversion view, turkey skin search,
bark tannin quantities and the absence of a direct animal leather route. Those
new native cases are authored but unrun while native execution is held.
The current gate is parent review of preparation, rather than an identified
external resource hold. On Windows, runners now use the shared retained-Job
supervisor; `tests/animal_harvest/validate_tanning.py` supervises the four serial
Atlas/harvest phases together. See `docs/leather-tanning-native-validation.md`.

`--negative-control` breaks the legacy pagination bound.
`--navigation-negative-control default|era|processor|output` separately breaks
the default route, era membership, processor filter or output rendering. Each
must fail its named runtime assertion. `--compile-only` compiles the selected
fixture without starting DreamDaemon; it provides no runtime evidence.

`node tests/crafting_atlas/navigation.test.mjs` exercises the actual website
template with an independently specified fixture and era/processor omission
controls. `scripts/atlas/check.mjs <generated-directory>` additionally checks
real exported PNGs, all recipe edges and acquisition navigation. DOM tests do
not establish browser appearance or actual-client input delivery.

`node tests/crafting_atlas/tanning.test.mjs` uses the committed game catalog with
the actual website template to check all tanning stage/resource links, costs,
acquisition, station construction and the tanning processor filter. It does not
generate or validate sprite images. `tests/test_tanning_atlas.py` adds source
drift controls and proves that omitting an essential stage breaks the full
turkey-to-leather chain, while existing leather and fur recipes remain linked.

`test_atlas_navigation.py` checks source-backed research tiers, maximum-era
separation, unknown/multiple tiers, actual processor conversions and source
drift. Existing `test_crafting_atlas.py` retains catalog freshness and procedural
source controls. CI selects this suite for PRs introducing executable tests;
existing suites remain opt-in afterward.
