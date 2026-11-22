# House plans

`code/game/objects/house_plan.dm`, `house_plan_checks.dm`, `house_designer.dm`;
described in `docs/house-plans.md`.

```
python3 tests/house_plans/test_sources.py
python3 tests/house_plans/run.py --byond-bin <bin> --output <empty-directory>
```

`test_sources.py` is offline: every part the planner offers is described, costs
what its recipe in `material_recipes_global.txt` says, and the window's page is
one sound raw string that writes the same design code as the plan.

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

The probe closes the native port in `world.New()`; that is not OS network
isolation. It does not open the window in a BYOND client.
