# The open-sea region

An open-sea region is an ocean world where crews build ships in the home
waters and make passage by a chart to islands and wrecks that are built when a
ship reaches them. The code is described in [craft-core.md](craft-core.md#the-open-sea).
This page is how to run one. Nothing here starts or changes a live server.

## The map

`maps/sea/open_sea.dmm` is 500 x 500 on two levels: rock under one level of
deep salt water, cut into sea cells of 100 tiles by tide races. The middle
three by three cells have no race between them: they are the home waters, 286
tiles of water on a side. The 16 cells round them are the pool.

The home island is drawn into the map in the middle of the home waters: about
200 tiles across and 31,000 tiles of land, with woods, ponds, outcrops of rock
to mine, flocks of turkeys, the harbour office board and a clearing in the
middle where arrivals land.

The map is written by a script, which also draws the island (the same one
every time), because the cell size lives in
`code/__defines/naval.dm` (`SEA_CELL_PITCH`, `SEA_CELL_MARGIN`, and
`SEA_HOME_SPAN`, the number of cells on a side of the home waters):

```sh
python3 tools/open_sea/make_map.py            # rewrite the map after changing the cell size
python3 tools/open_sea/make_map.py --check    # exit 1 if the map is stale
```

Changing the cell size on a world that already has a save moves the tide races
through whatever players built, so treat it as a new world.

## Adding the region to a group

Add a region to the group config ([scripts/shard-group](../scripts/shard-group/README.md)):

```json
{ "id": "sea", "name": "The Open Sea", "kind": "OCEANIC", "port": 1744, "map": "maps/sea/open_sea.dmm" }
```

Then `setup --region sea` and `start --region sea` as for any other region.
Players reach it the way they reach every region; new arrivals land on the
home island.

## What players do there

1. Build a hull of floors over the water off the home island, set a tiller on
   it and commission her. Give her a rigged mast or a running engine: a hull
   with nothing to drive her cannot make passage.
2. At the tiller choose **Weigh anchor**, then **Open sea chart** and **Lay a
   course** for one of the places in sight, or **Steer by compass** to look for
   more. She puts to sea and lies alone in open water while she makes the
   passage.
3. When she arrives the island or wreck is there and she anchors off it. The
   tiller's ordinary orders sail her about inside those waters.
4. Lay a course for **the home waters** to come back.

The harbour office's paid work is switched off for now (`npc_jobs_enabled`
in `code/modules/craft/contract.dm`); the board stands but offers nothing.
When it is switched on:

The **harbour office board** on the home island pays crews of registered
ships in silver: for surveying a named island (anchor off it, then report at
the board; the island is then on every ship's chart from any distance) and for
salvage (set one crate out of a named wreck down by the board; the office
keeps the crate, the crew keeps what was in it). The pay is 10 coins plus the
miles for a survey and 20 plus the miles for salvage.

Two ships at sea can meet. The chart lists any sail in sight; **Close a sail**
steers for where she is now, and on coming up with her the ship heaves to in
the same water, where the crews can hail, trade or board. Whichever sails on
parts company. A ship running dark is only made out from close by.

An island or wreck is taken away ten minutes after the last ship and the last
person have left it, with whatever was left there. A mooring post built on it
makes it a harbour that stays; four sites can be harbours at once.

## Limits

- 16 cells serve everything outside the home waters: ships at sea, and up to 8
  loaded sites. When none is free a ship cannot put to sea or stands off the
  place she reached until one is.
- Only hulls built at a tiller make passage. Slipway ships, the carrier and
  modular boats stay in the waters they are in.
- Not verified: a real save and load of an open-sea world, and play in a game
  client. A native boot on this map ran without runtime errors and raised the
  home island (2026-11-12, Linux, 516.1688).
