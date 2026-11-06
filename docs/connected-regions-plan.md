# Connected regions plan

Val's goal (2026-11-06): procedurally generated regions that players can travel
between by train, foot path or other means, such as several Moon colonies that
are separate maps but one connected place. This page plans that work. The first
step, the Moon as its own world, is built
([space settlement roadmap](space-settlement-roadmap.md), `code/modules/space/moon_world.dm`).

## What exists

- **Regions** are separate DreamDaemon worlds in one shard group
  (`scripts/shard-group/shard_group.py`, at most 16), each with its own map,
  save and port. The mainland (Gaia) is where new characters start; every
  other region follows its epoch.
- **Travel** moves a character, what they wear and carry, through the transfer
  agent ([region travel](../tools/transfer_storage/README.md)). Gates are
  admin-placed; trail markers are player-built and open once an admin approves
  them; launch pads are trail markers limited to surveyed worlds.
- **Generated maps** come from `tools/procedural_maps`: a seed and preset give a
  verified bundle, `playable --skin <skin>` turns it into a region map, and
  `survey` gives the coarse map a probe flies over.
- **Party trains** run between a land's station and the shared rail yard world.

## Design

### Bodies and colonies

A *body* is a family of regions that share ground, climate and rules: Earth,
the Moon, Mars. A *colony* is one region of a body, with its own generated map
and region id. The Moon's regions are `moon`, `moon2`, `moon3` and so on; every
id starting `moon` is lunar (`survey_region_lunar`), so Moon rules (no dust, its
cold, terrain names, the 1969 epoch gate) apply to each colony without new code.
Each colony is generated from its own seed with `playable --skin moon` and gets
its own survey map, so a probe can scout it and a lander can set down on it.

Colonies are only as many as the host can keep: about 250 MB of RAM each while
awake, nothing while asleep. They sleep when empty and wake when someone
travels there, as regions already do.

### Links between regions

A link joins an edge or a point of one region to another. Three kinds, all on
the existing travel path so goods and characters move exactly as now:

1. **Foot paths (edge exits).** Walking off a marked map edge travels to the
   matching edge of the neighbouring colony. The generator reserves an exit
   strip on each linked side (no ridges, no ice) and records it in the bundle,
   and the region config lists `links` as `{"side": "E", "to": "moon2"}`. A
   generated map knows its neighbours at build time, so no admin approval is
   needed for these; they are part of the world.
2. **Rail links.** A station on each colony, joined by a train that travels as a
   party train does today but between two colonies instead of to the yard. The
   generator places a station plot near the linked edge; players build the
   track and office, so the line is something they earn.
3. **Player-built links** stay as they are: trail markers and launch pads need
   an admin's approval.

On an airless body, walking a foot path needs a sealed suit, and arriving
players appear at the far edge in the open, so links between Moon colonies are
crossed in a suit or a rover (rovers travel with their crew in a later step).

### Generation

A *body plan* file (`config/space/bodies/moon.json`) lists the colonies, their
seeds, sizes and links. One command generates every colony from it: the bundle,
the region map, the survey map and a group snippet with ports and links. Links
must be symmetric and each linked edge must have open ground; the generator
refuses a plan that breaks either rule. Because maps are seeded, regenerating a
plan reproduces the same colonies.

### Epochs and home

Colonies keep Val's rules: the Moon opens in 1969 and Mars in 2026; one home
world per account (a claimed bed keeps it, otherwise home reverts to the
mainland); and every region follows the mainland's epoch.

## Steps

1. **Done:** the Moon as its own world (`moon`), probes and landers choosing
   the Moon or Mars, epoch gates, one survey record per world in each console.
2. Body plan file and a `colonies` command that writes every colony's map,
   survey map and group snippet from it.
3. Edge exits: reserved exit strips in the generator, `links` in the region
   config, and an edge-travel hook that hands a walker to the travel path.
4. Colony stations: station plots in generated maps and a party train that runs
   between two colonies.
5. Rovers crossing edge exits with their crew and cargo.
6. A second Moon colony on the live group, after Val agrees to the RAM and
   ports.

Adding any region to the live group, or starting a new world on the host,
needs Val's approval.
