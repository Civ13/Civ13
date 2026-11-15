# Construction weathering across a world load

`python3 tests/construction_weathering_load/run.py --byond-bin <BYOND-bin>`
compiles the production game types and persistence code with normal startup
disabled and runs a synthetic 6x4x1 world through Save_World, ClearMap and
Load_World.

A straw wall, a thatch roof and a wooden wall weather for two serviced seasons
and one unserviced season. After the load, their health and the unpaid season
debt are unchanged, the debt is charged once, and later seasons keep counting.
The probe also checks the year-based lifetimes (64, 256 seasons), the examine
text and last-year warning, a straw wall repaired with planks at the missing
share of its build cost, and a thatch roof repaired with thatch roofing.

`--negative-control roof-debt` drops `seasonal_construction_due` from roof
saves and must fail with `unpaid season is carried over (1, 0, 1)`.

The probe also covers pacing: a roofed wall weathers at three quarters of the
rate and a founded, roofed one at half; a 300-season backlog stops at the
last-year warning, then the last-season warning, then a ruin, and only then
crumbles; a worn-out wall stands as a named, cracked ruin that holds nothing
up; the roofs over it sag for a minute, one settles when it is propped and the
other falls; and a repaired ruin is a wall again. `--negative-control shelter`,
`pace`, `ruin` and `sag` each remove one of these and must fail its assertion.
The run takes about 80 seconds of game time for the sag.

Not covered: a connected client seeing the warnings, full season queue work,
or Gaia's real save.
