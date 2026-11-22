# Train sheets

## `probe.dm`

A native probe for `code/modules/1713/train_draught.dm`,
`train_draught_checks.dm` and `train_works.dm`. The three ready-made sheets
pass their checks and read back from their codes; bad codes are refused (an
unknown car, a drawn car of the wrong length or with too few sections, an
unknown edge or fitting, too many cars). A drawn car is a car kind with its
own layout. Each `train_sheet` check fires: no engine, a main-line engine
without a tender, a stray tender, a long train with no brakes, a sealed car,
cold lockers with no bunker, a car blocked down the middle, a train over the
tile cap and an empty sheet. Every key has a part description. The rail
works refuses missing research, missing stock and track with no room, builds
the branch train heading north from the rail tile in front of it, couples
every section into one train, lays out and furnishes the drawn saloon,
spends its stock, blocks a second build, draws the train back car for car,
and a drawn car packs into a kit that keeps its design.

    python3 tests/ecology_spawning/run_linux.py . tests/train_draught/probe.dm 300

## `test_train_sheet.py`

Stdlib source contracts: stock cars cost their kits' recipes, every kit kind
can be drawn, every table row is described and uses existing sprite states,
the rail works is crafted and gated, and the files and docs are wired.
