# Provinces

Each continent is cut into provinces that follow the land: coasts, big
rivers, lakes, mountain ranges and narrow straits. Provinces are the units
factions will hold on a continent (the continent control plan: recruitment
stations work only in a province the faction holds, plus stake, ranks and
sieges). Each faction's stake is counted and shown (Faction > Province Holdings,
Admin > Land Status), sides take and lose provinces by it, and recruitment
stations follow the holdings once the preview ends.

## Files

`maps/provinces/<map>.txt`, beside `maps/heights/<map>.txt`. The game finds it
from the map's `terrain_height_file` (`code/modules/provinces/provinces.dm`),
so a map with no height file, or no province file, has no provinces.
Expedition lands have none.

```
civ13-provinces 1
size WIDTH HEIGHT
z Z
province 1 North Coast
province 2 West Riverlands
...
<HEIGHT rows, north row first, WIDTH characters each>
```

`z` is the surface level the file was cut from. Every level of the map uses
the same rows, so a cave or an upper floor belongs to the province under it.
`.` is open sea in no province (more than 8 tiles from land); the other
characters are province ids, `1`-`9` then `a`-`z`. A bad file is ignored with
a debug log, leaving the land without provinces.

## Making them

```
python3 scripts/provinces.py --map maps/nomads/nomads_gaia.dmm --z 2 \
    --heights maps/heights/nomads_gaia.txt --flow maps/heights/nomads_gaia.flow.txt \
    --out maps/provinces/nomads_gaia.txt --render gaia.png
```

| Map | Surface z |
| --- | --- |
| nomads_gaia, nomads_desert, nomads_jungle | 2 |
| nomads_americas_north, nomads_americas_south, nomads_europe, nomads_asia | 1 |

How the tool works:

1. Land is every non-water tile; rock walls count as land.
2. The number of provinces is one per 12,000 land tiles, between 4 and 12
   (`--count` overrides it). Starting points are shared out between
   landmasses by size; pieces too small for a province of their own get none.
3. Provinces grow outward from their starting points over a cost map:
   ground 1 per tile plus 1.5 per level climbed, rock walls 6, rivers and
   lakes 30, the sea 40. Borders settle where the cost is high, so on rivers,
   lakes, ranges and straits.
4. Six rounds move each starting point to the middle of its province to even
   out sizes. A province under 30% of the planned size merges into the
   neighbour it shares the longest border with.
5. Names are a compass part of the land plus the best-fitting terrain word
   not yet used there (Highlands, Hills, Riverlands, Lakelands, Coast, Sands,
   Jungle, Snowfields, Marshes, Lowlands, Plains).

The output is deterministic. Review the render before committing, and rerun
after changing a map's land, water, heights or rivers. Names and border
characters may be edited by hand; rerunning the tool overwrites them.

## Stake

Code: `code/modules/provinces/province_stake.dm`. Reckoned every 10 minutes.

- **Resident, 1 point.** An account on the faction's roster for 72 hours,
  whose claimed bed has been theirs for 72 hours and stands within 40 tiles of
  one of the faction's fastened halls or on a plot the faction registered.
  The account must have played 10 hours in all on this land, and 4 active
  hours over at least 3 different days of the last 7. Activity is counted
  every 10 minutes for each player with a living character who is not idle
  (10 minutes without input), in `map.faction_recruitment["province_activity"]`.
  A resident counts in the province their bed stands in.
- **Hall.** 2 points per tier of the faction's best standing hall in the
  province, never more than its resident points there.
- **Nations pool.** Factions of one nation add up. Pooled residents count 1
  each up to 10, a half each up to 30 and a quarter after that.
- **Leading.** The largest stake with at least 6 points from at least 4
  accounts, 35% of the stake there and 1.25 times the runner-up.

Faction > Province Holdings shows a player which province they stand in,
whether they count as a resident (and if not, why), and every province's
stakes. Admin > Land Status shows the same table.

## Holding

Code: `code/modules/provinces/province_holding.dm`, run after each stake count.

- A side (a nation, or a faction outside one) that leads an unheld province
  for 72 hours in a row takes it.
- A holder keeps it until a rival out-stakes it for 72 hours in a row: 6+
  points from 4+ people, 35% of the stake there and 1.25 times the holder.
- A holder below 6 points from 4 people is warned and loses the province
  after 48 hours unless it recovers. Destroyed beds and halls are rebuilt in
  that time or the province goes.
- A side holds at most 3 provinces of a land. (The plan's 6 worldwide needs
  the coordinator and is not built.)
- Leaders are told when a hold slips, recovers, is challenged, taken or lost.

**Stations.** On a land with provinces, a recruitment station works only in
a province its faction's side holds, and only when that faction has 3
residents of its own there. An idle station keeps its faction, policy and
queue; examining it says why it is idle, and a leader cannot designate a
station where it would be idle. Member starts use working stations only.
Lands without provinces, such as expedition islands, keep every station
working. The rules start 21 days after a world first counts stake
(`province_rules_from`, durable), the 14-day preview plus 7 days' grace.

## Continent resources

Code: `code/modules/provinces/continent_resources.dm`. Each continent is rich
in its own resources and short of the others, so no one continent leads to
every age:

| Continent | Rich in (2x) |
| --- | --- |
| Gaia (start) | copper |
| Jungle | tin |
| North America | iron, lead |
| Europe | coal, zinc |
| Asia | saltpeter, silver, gems and diamonds |
| Desert | sulphur |
| South America | gold, silver, bauxite |

- Away from their home, bulk ores (copper, tin, coal, zinc) and precious finds
  (silver, gold, diamonds, gems) come at half the rate, strategic ores
  (saltpeter, sulphur, lead, bauxite) at a third. Iron stays normal everywhere.
- Gaia keeps tin at the normal rate, so a new player reaches bronze and iron
  alone, and has no bauxite or uranium: from combustion on, a faction needs
  imports or a foothold on another continent.
- The factors apply to rock walls (`floor_attackby.dm`), gold and silver lodes
  (`lode.dm`), gem pockets (`gemstones.dm`) and the Americas' mountain seams
  (`mountain_seams.dm`; a scarce seam load sometimes gives only stone).
  Expedition islands and battle maps mine as before.
- Lowered rates phase in: normal for 7 days after a world first uses them,
  then at least three quarters, then final after 14 days
  (`faction_recruitment["continent_resources_from"]`). Raised rates apply at
  once. Stockpiles are untouched.
- Faction > Province Holdings and Admin > Land Status show the line.

Still to come from the plan: rich provinces with renewable seams capped by
rank, rubber trees, land oil only in the Desert, Gaia's crop bonus.

## Checks

`python3 tests/provinces/test_source.py` (offline suite `provinces`): every
continent's file parses, matches its map, puts every land tile in a province
and has 4-12 unique names; the generator puts a border on a river; the DM
reader expects the same format.
