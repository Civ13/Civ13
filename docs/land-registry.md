# Land registry and deeds

Code: `code/game/mob/groups/land_registry.dm`. Tests: `python3 tests/land_registry/test_source.py`;
native probe `python3 tests/ecology_spawning/run_linux.py . tests/land_registry/probe.dm`.

Step 5 of the bureaucracy and currency plan. Land is registered with a faction and held by deed.

## Boundary stones and plots

`/obj/structure/boundary_stone`: 2 stone, economy & production, gated on Trade & Coinage
(`early_economy`). It reuses the cairn sprite. A faction's registrar (its leader, or anyone with the
faction's registry power, see `docs/faction-offices.md`) uses a stone and picks another stone at the
opposite corner. The plot is the rectangle between them: 2 to 32 tiles on a side, never
overlapping another registered plot, at most 60 per faction. The registrar names it and receives
its deed.

At a stone of a registered plot, the registrar can read the register, set the land tax (0-100
silver a week), reissue the deed (the old one becomes void, for a lost deed or land taken back),
rename the plot or strike it from the register. Anyone else reads who it belongs to.
Use a hammer to dismantle a boundary stone. This removes the marker, not the plot or its deed.
To unclaim the land, use the registrar's **Strike the plot from the register** action instead.

## Deeds

`/obj/item/land_deed` is never crafted; only the register writes one. Whoever holds the deed holds
the land, so land is sold by handing the deed over. A valid deed is the master key of its plot:
standing beside a player-built keyed door or a chest on the plot, the holder can lock or unlock it.
Jail doors and the faction strongbox are excluded. Examining a deed checks it against the register.

## Land tax

Tax is owed for the time since the plot was paid through, in weeks, times the rate. Anyone pays it
at the faction's strongbox ("Pay land tax from my hand"), and paying ahead is allowed. Payments and
registry changes go into the treasury ledger. The game never evicts anyone; the faction enforces
what the register says.

## Saved state

`map.faction_recruitment["plots"]`: faction -> plot id -> list(name, x1, y1, x2, y2, z, deed serial,
tax, paid through, registered to). Renamed through `faction_roster_rename()` and cleaned by
`faction_roster_normalize()`. `faction_power()` in `faction_offices.dm` decides who acts for the registry.
