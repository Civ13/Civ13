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

Not covered: a connected client seeing the warnings, full season queue work,
or Gaia's real save.
