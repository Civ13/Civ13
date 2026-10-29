# Production food progression probe

`run.py --probe barrels` covers the portable barrel's specialized ingredient
handler: actual paid ore units and exact capacity, subtype/final-hand cleanup,
actor/lid/stock/save guards, whole/depleted/trace manure, partial/zero-transfer
refusal and a real saved barrel reagent entry. It does not exercise inherited
fruit conversions, dispenser locks or full-game reachability. Compile-only starts
no world; use a new evidence directory and the explicit current compiler version
as for the other probes. Native execution is separate from compilation. The
eight source/data hashes and bounded text evidence are retained by selected CI.

`run.py --probe cutting` runs the cutting-board slice separately from crop and
storage. It covers all seven frozen input types and original yields/delays,
live food ownership, continued age/rot, salt/reagent preservation, poisonous and
already-minced subtype refusal, two preparers, interrupted/replaced/tool-lost/
save-crossed work, scraping and a real board-plus-food-child save round trip.
Its board subtype and generated food source bound waits to 2 ds while
retaining production age charges; preparation delays are independently checked.
It supplies actors, food and knives and does not establish player bootstrap,
graphics, full-game elapsed timing or full-world restoration.
Frozen trace controls use real holder pruning at/around 0.01: unsafe two-output
splits are refused intact; successful splits and one-output controls retain the
stored cyanide/nutrition totals. A direct holder negative control demonstrates
the loss without the board guard. Traces added during a wait are revalidated.
Use `--expected-byond-version 516.1688` for the current
compiler. `--compile-only` launches no world and explicitly reports runtime not
run. `--evidence-dir <new-directory>` retains logs/metadata/results without
overwriting prior evidence; selected CI uploads its bounded text evidence.

Salted meat provisionally consumes one unit of table salt: fresh meat and
cutlets get twice their ordinary decay limit, and dried meat gets four times its
ordinary limit. The same fraction of life remains after either action; salting
does not make rotten food safe. Cut salted slabs into cutlets and dry them, or
use a salt condiment directly on dried meat. The paid state survives both routes.
`test_salted_meat_sources.py` checks offline source contracts only. The existing
`preservation.dm` fixture additionally exercises direct and repeated salting,
depletion, drying, and the actual save entry round trip when its native runner is
authorized; preparing it does not execute those assertions.
`test_meat_cutting_model.py` binds an offline behavior model to both cutting
handlers and the save/decay source contracts. It covers rot and expiry boundaries,
legacy missing fields, an explicitly disabled decay limit, and a later decay
callback after restoration. It does not execute the DM handlers or serializer.
An older bear slab that has not reached its own expiry can still be cut; the
cutlets become rotten immediately if their inherited age meets their rot limit.
`test_drying_spoilage.py` checks the rack's conversion admission source and an
offline model of restored spoiled inputs, thresholds, missing legacy fields and
zero decay limits. The preservation fixture also prepares a real encoded-input
save/refill case and salted/unsalted thresholds; it must be run separately to
establish native behavior. Rejected inputs remain on the rack for removal.
For dried products, the save hook drops the item with a zero live decay limit
and the original limit encoded in its name. The fixture checks that paused state
after load, then refills the rack and removes the product through its normal
interaction before checking its active limit, paid salt, age and depleted food.
`test_dried_rack_save_contract.py` checks that sequence offline; it does not run
the native serializer or rack.

The opt-in `preservation_run.py --probe decay-rate` diagnostic saves and loads a
salted dried item, removes it from the rack before its constructor callback wakes,
and compares two age samples with an ordinary reference created in the same tick.
It replaces the food wait with 20 ds and the rack restart wait with 21 ds while
retaining the production age charge. `--decay-rate-control omit-restart` removes
only the delayed restart in the generated source. A missed synchronization window
fails rather than interpreting ambiguous samples. This diagnostic is not selected
by ordinary CI and is not evidence until its baseline and control are executed;
the accelerated schedule does not establish full-game elapsed-time behavior.

Run `run.py --byond-bin <516.1681-bin>` with a verified Python interpreter.
Both food runners default to the historical 516.1681 compiler. Select the
current 516.1688 compiler explicitly with `--expected-byond-version 516.1688`;
other versions and mismatched compiler output are rejected. The selected CI food
lane passes its pinned version to the crop, storage and preservation probes and
their existing controls. Rack-save remains a separate opt-in lane.
Run again with `--negative-control` to remove the seed debit in a generated
source copy and require the planting assertion to detect that regression.

The probe compiles all production sources without maps or normal world/global
startup. It supplies a synthetic 6x3x1 temperate plot, a map metadata adapter,
observer/reagent initialization and a human adapter that skips normal actor
construction and skill rewards. Actual turf planting, seed consumption,
occupied/unploughed rejection, plant construction, growth, water/soil behavior,
knife harvest, actual tomato produce construction and two returned seeds run
through production handlers. Only the one-minute growth wait is shortened to
two ticks. Winter development pauses and spring resumes with fresh water nearby.
The actual custom save entry encoder/loader writes a live winter crop to a
temporary savefile and recreates its type/location, stage, stored water,
nutrition, radiation and climate/season lists. The restored crop remains paused
in winter and develops after spring begins, through its constructor-owned wait.

Runtime uses unique temporary storage and tracked name data, with no production
config or saves. It retains compile/runtime logs, result, metadata and generated
sources there, and removes its unique checkout outputs in `finally`. The daemon
has a 30-second bound; only the launched process is stopped on timeout. BYOND
may perform its usual account/network startup. No game HTTP/Topic operations,
production restart or season change are performed.

This is production-path integration evidence, not a player bootstrap or full
season-transition demonstration. Seeds, knife, nutrition, actor and prepared
soil are supplied. It does not prove walking access, craft/research/tool gates,
inventory interactions, elapsed gameplay timing, map-wide climate transitions,
full-map save/import sequencing or graphical appearance. Crop entry restoration
does not prove transactional map loading or constructors at full map scale.
Those remain under #3048/#3049.
No game behavior or artwork is changed.

The production dirt turf save allowlist must restore nondefault soil nutrition.
`--soil-negative-control` removes only that allowlist addition in a generated
source and requires this nutrition assertion to fail. This additional control is an explicit local check; CI
runs the normal probe (including soil restoration) and existing seed control. Recovery tokens are excluded from the dirt allowlist.
