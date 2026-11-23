# House plans

`code/game/objects/house_plan.dm`, `house_plan_checks.dm`, `house_designer.dm`,
`house_plan_pegs.dm` and the builders' pegs in `build_markers.dm`; described in
`docs/house-plans.md` and `docs/build-markers.md`.

```
python3 tests/house_plans/test_sources.py
python3 tests/house_plans/run.py --byond-bin <bin> --output <empty-directory>
```

`test_sources.py` is offline: every part the planner offers is described, costs
what its recipe in `material_recipes_global.txt` says, and the window's page is
one sound raw string that writes the same design code as the plan. It also
checks the pegs' kinds against their art and their saved fields.

`run.py` compiles the game without its maps around `probe.dm` and runs it once
with the pinned BYOND. The probe's world is soft ground with open air above.
It checks the tables against the built objects (storeys carried, reach,
foundations), then judges each plan as drawn and really builds it: every wall,
window, door and pillar as its object, every roof tile through
`building_design_error()` and `building_construct_roof()`. The plan's verdict on
each roof tile must be the game's, for the three ready-made plans and for
houses with each fault: a room too wide, stone on soft ground, three timber
storeys, stone over timber, walls on open air, a lone pillar upstairs and a
wall over nothing. It also covers the warnings, the notes and refused codes,
and writes `designer.json` (the window's data and answers for four plans) to
the output directory.

Last it pegs the two-storey house out (`house_plan_peg_out()`), builds it as
its pegs ask and checks the tags, that an unfloored storey takes no pegs, that
each peg goes when its tile is built and that a note's peg stays.

The probe closes the native port in `world.New()`; that is not OS network
isolation. It does not open the window in a BYOND client.
