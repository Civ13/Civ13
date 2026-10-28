# Production food progression probe

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

Run `run.py --byond-bin <516.1681-bin>` with a verified Python interpreter.
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
