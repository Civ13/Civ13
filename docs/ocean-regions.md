# Ocean regions

Five oceans fill the water between the lands of the earth group, so every sea
edge of every land leads somewhere: the Atlantic, the Pacific, the Indian, the
Arctic and the Southern Ocean. Each is its own world (shard kind `OCEANIC`).

| Region id | Map | Size | Notes |
| --- | --- | --- | --- |
| atlantic | `maps/nomads/nomads_ocean_atlantic.dmm` | 600 x 900 | Gaia and Greenland insets |
| pacific | `maps/nomads/nomads_ocean_pacific.dmm` | 900 x 900 | Closes the loop between Asia and the Americas |
| indian | `maps/nomads/nomads_ocean_indian.dmm` | 600 x 600 | |
| arctic | `maps/nomads/nomads_ocean_arctic.dmm` | 1000 x 300 | Pack ice along the north; west and east join |
| southern | `maps/nomads/nomads_ocean_southern.dmm` | 1200 x 300 | West and east join; Antarctica to the south |

Code: `code/game/objects/map_metadata/nomads/nomads_ocean.dm` (metadata) and
`code/modules/naval/ocean_regions.dm` (the ocean area, the breakers turf). Which stretch of which ocean edge meets which coast is in the
world links table ([world-links.md](world-links.md)): `world_sea_links`,
`world_oceans` and `world_insets` in `code/modules/persistence/world_links.dm`.

## The maps

`python3 tools/ocean_maps/generate.py` writes every ocean map from
`tools/world_links/world_links.json` (`--check` exits 1 when one is stale). An
ocean is one level of deep salt water and nothing else but:

- a small rock in the middle with the `JoinLateCiv` landing, where a traveller
  with nowhere better to stand is put down;
- pack ice along an edge the table gives `ice` (the Arctic's north), solid near
  the edge and loose floes beyond;
- breakers round each inset: an island land's waters inside the ocean.

The metadata turns off everything a land has: no dug underground
(`dig_down_underground`), no open-air levels (`building_levels = 0`), no wild
plants or land animals. Sea life keeps its own cap.

## Memory

The largest ocean, the Pacific (810,000 tiles), measured with
`python3 -B tests/zone_persistence/real_map.py --map maps/nomads/nomads_ocean_pacific.dmm --loads 1 --settle 30`
on BYOND 516.1688: startup 182 s at 851 MiB, save 69 s, write-run peak 986 MiB.
That is about two thirds of a land region's load peak (1350-1560 MiB in
[earth-continents.md](earth-continents.md)), since an ocean has one level and
almost no objects. The harness's roof check has nothing to build on at sea, so
its reload run was not reached; the smaller oceans were not measured.

## Insets

Gaia and Greenland have sea on every side, so their edges cannot face one ocean
edge. Each has an inset in the Atlantic: a box of breakers whose four sides lead
to that land's four edges. Ship crossings into and out of insets come with the
ship edge crossing work.

## Sailing over an edge

`code/modules/naval/ship_edge_crossing.dm`. A commissioned ship within four
tiles of a map edge that leads somewhere (a sail or `both` link in the world
links table) gets "Sail over the horizon" at her tiller. She must have a mast
or a running engine and two crew awake aboard, and pass every check a crossing
already makes (load, landfall rest, no upper deck). She then crosses
(`cross()` in `ship_crossing.dm`) with the arrival side and the fraction along
the stretch in the first crew member's payload (`sea_edge`). The far side
builds her on the facing edge at the matching place in its stretch, searching
outward along it and inward from it for free deep water
(`sea_edge_anchorage()`).

Island lands: a ship off any edge of Gaia or Greenland comes out beside that
side of the island's box in the Atlantic, and a ship in the Atlantic lying
against a box comes out on the island's edge on that side.

The whole crew leave as one party: `depart_party()` in `region_travel.dm`
sends every crew member's payload in one escrow. The transfer agent keeps one
transfer in flight per land, so crew sent one after another waited on each
other and could be left behind. A party is capped at `REGION_TRAVEL_PARTY_MAX`
(1,000,000 bytes as sent, under the agent's 1 MiB request limit); whoever
would go past it stays and is told so.

All of this waits for the group option `edge_travel_oceans` (group JSON,
written into each region's `shard_region.json` by `shard_group.py`); it is off
by default.

## Sites at sea

`code/modules/naval/ocean_sites.dm`. Each ocean has a fixed list of sites,
rolled from its id so every start finds them in the same places: about one for
every 30,000 tiles, at least 60 tiles from the map's edge, clear of the landing
rock, pack ice and the insets' breakers. A site is one of:

- an islet: a small island with grass, trees, rock and a fresh pond, built by
  the open sea's island builder (`open_sea_sites.dm`);
- a reef: shallows with coral heads awash. Shallow salt water is the richest
  fishing at sea (`fishing_grounds.dm`);
- a wreck: planks adrift with crates of salvage;
- a sea mark: a named rock to steer by.

Every 10 seconds the sites look for ships and people. A site rises when a
ship or an awake player comes within 40 tiles of its square, and lingers
`SEA_SITE_LINGER` (10 minutes) after the last of them is more than 60 tiles
away, then the sea closes over it. Nothing is kept in a registry: a raised
site is saved with the world like anything else, and is known to be up by
what lies at its middle. A site stays up while someone is on it, a ship lies
near it, a bunk on it is kept as home, or a mooring post that takes ships makes
a harbour of it (up to `SEA_KEPT_CAP`, 4, per ocean). Nothing rises or goes
under during a world save.

Sea life keeps its own cap (`sea_life_cap` in the metadata), and someone who
logs out at sea stays aboard and wakes there, as anywhere else.

A ship nobody has been aboard for a week (awake, asleep or logged out) and that
lies at no harbour founders and goes down, so the oceans do not fill with
hulks. Her tiller keeps `unmanned_since` (world.realtime), saved with her.

## Round the world

The Arctic and the Southern Ocean have `wrap` in the world links table: their
west and east edges join. A ship off either of those edges is offered "Sail
over the horizon" as at any linked edge, needs the same mast or engine and two
crew, and comes out at the other edge of the same ocean at the matching place
along it (`sea_edge_wrap()` in `ship_edge_crossing.dm`). She stays in the same
world, so nobody travels and nothing is sent.

The probe for sites, upkeep and the wrap is `tests/naval_carrier/ocean_sites_probe.dm`.

## Straits

`code/modules/naval/strait_boom.dm`. A boom winch (20 iron, vehicle parts,
after Wagons and Ships) is built on a shore facing the water. Iron used on it
lays a boom of floating segments, one iron a tile, straight across to the far
shore, at most 60 tiles. A raised boom is dense, so it stops every hull and
swimmer.

- The owner (the builder, or anyone of the same civilization) raises and
  lowers it by hand and sets a toll in money value. With a toll of 0 anyone
  may lower it.
- Anyone else pays the toll with coins at the winch. The coins go into the
  winch, the owner takes them out, and the boom drops for a minute. It does
  not rise under a hull lying over it.
- A ship at full ahead that runs against it rams it (`boom_ram()`, called
  from `sail_hop()` before she would stop). The segments across her bow
  break, one bow plank is lost on each (the ledger counts the holes), and she
  drops to slow ahead.
- A hatchet or knife cuts a segment in three minutes, from a boat or a shore.
- Iron on the winch mends broken segments, one iron each.
- On a land with provinces, a boom goes only where no other side holds the
  province.
- The winch finds its boom by walking from its own tile, so nothing needs
  references across a save. A boom saved lowered loads raised.

The named straits (`named_straits`) tell a crew when she enters one: Gibraltar,
the Dardanelles, the Bosporus and Sicily on the Mediterranean; Dover and the
Danish straits on Europe; Bab-el-Mandeb on Africa; Hormuz and Malacca on Asia.
The Bering Strait needs a link between Asia and North America, which the maps
do not have yet.

The probe is `tests/naval_carrier/strait_boom_probe.dm`.

## By plane

Planes fly off linked edges and are carried over the oceans, which have no air
level; see "Over the map edges" in docs/aircraft-crossing.md
(`aircraft_edge.dm`). The probe checks are in `tests/aircraft/crossing.dm`.

## Switch-on

Everything above waits for the host's group option `edge_travel_oceans`. Once it
is on (`region_posts_retire.dm`):

- Building a trail marker is refused, and admins cannot place trails. Admin >
  Send Player to Region still moves anyone stranded.
- Once a minute after the world has loaded, every trail marker and plain trail
  becomes a signpost in the same spot. The signpost keeps the post's name, the
  post's 10 wood is left beside it, and its old destination goes to the game
  log. A player still waiting on a trail request is told. Launch pads, railway
  stations and the hidden gates of crossings stay.
- Set out on a voyage no longer lists the continents' sea lanes, and Leave
  these waters is not offered; ships sail over the horizon instead. Chart
  voyages to expedition lands stay. Fly to another land only says to fly off
  the edge (`aircraft_edge.dm`).

The probe is `tests/edge_crossings/posts_probe.dm`.

## Not yet

These maps are not in any live group until the host step that adds the seas.

## Indian Ocean reef shelf prototype

`tests/ocean_maps/indian_reef_shelf.dmm` is a deliberately non-admitted 40 × 30
map fixture, not a replacement for the Indian Ocean world. Its small arrival
rock is at (6,15). A yellow buoy at (26,8) marks the south side of the reef;
the reef itself is centered on (26,15), with bedrock ridges, two cuts and
shelf water on z2. Its open surface stays on z1. It demonstrates an authored
location with a navigable, bounded seabed directly below open, ordinary
saltwater, not a route through breakers or a boat's hull.

The metadata marks the compiled second plane as below the first. There is no
runtime allocation, cave digging, sea conversion sweep or new dive verb.
Existing `Dive`, `Surface` and the corresponding HUD actions resolve the
same x/y via the existing multiz links. The authored cells use the standard
sea-layer turf and its default shelf depth; breath and fatigue, scuba and
sealed-suit handling, and obstruction checks remain where they already live.
This fixture does not opt into the map-wide simulation that populates the
submarine sea layer. It adds no extractable petroleum, no crossings and no
new production charter or region settings.

Regenerate just the fixture with `python3 -B tools/ocean_maps/reef_fixture.py`.
A full-size 600 × 600 Indian map would still allocate 360,000 additional turf
slots, even if only this reef were traversable. Before considering that
change, measure pinned-toolchain startup and resident memory, and verify a
saved character and item on the shelf reload and can surface. Offline fixture
checks do not establish those properties or real-client presentation.
