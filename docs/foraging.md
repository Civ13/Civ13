# Active foraging: design and experimental phase one

## Goal and boundaries

Give explorers a deliberate way to search outdoor terrain for small overlooked
resources, inspired by Project Zomboid's exploration loop, not its code, UI or
assets. Civ13's existing bushes, wild crops, trees, mining, sifting and hunting
remain the primary resource systems. Foraging must not become a source of free
high-tier materials or a way around research.

It is on for Persistence worlds and off elsewhere unless a map opts in.

## Phase 1: bounded search and shared scarcity

- `Forage nearby` in Crafting searches the tile under the player.
  It is on wherever Persistence is on (Val, 2026-11-10). Other maps opt in through `foraging_enabled`, which is false by default.
- Search takes 30 uninterrupted seconds. Existing `do_after` cancels movement,
  active-hand changes and incapacity and prevents repeated actions. Revalidate
  connection, map policy, exact turf, habitat and persistence epoch on completion.
- Open grass/dirt yield one stone or small wood piece; ordinary beach/desert sand
  yield one stone (phase 4 widened this, see below). Caves, snow, farmland,
  water, roofs, dense/structured/covered tiles and invalid outdoor climates are
  excluded.
- A fixed 8x8 coordinate patch shares four units across all players and categories.
  A successful completion spends exactly one. No preview, bonus yield or individual
  player cache (phases 4 and 5 added farming practice and renewal). Traversing a boundary accesses
  a different patch, intentionally rewarding exploration.
- Depletion is held in a hidden, anchored, nonflammable `/obj/foraging_cell` at the
  patch's fixed origin. The partial object saver explicitly includes `remaining`.
  This avoids map metadata (excluded from export), unsaved globals and turf-field
  resets. Ground replacement retains the ordinary object; movement overrides refuse normal,
  forced and persistence relocation (including broken-floor falling).
  Exhausted records remain. No new workers, global scans or per-tick checks.
- Both the local tile and anchor have 64-content upper bounds. Duplicate or malformed
  records fail closed. At most one record per searched 8x8 cell: 2,772 for a
  500x350 level. This is an object-count bound, **not a measured memory claim**.
- Save/load/recovery admission fences prevent an in-progress search crossing a
  generation boundary. No action datum or actor reference is stored in the save.

The verb remains visible when disabled and explains that fact. No client
overlays or new art are included.

## Phase 2: storage and economy acceptance

`tests/foraging/probe.dm` runs the production search, `forage()`, with only the
client check and the do_after wait swapped for staged events. CI runs it with
the other isolated resource probes. It shows:

- a completed search pays one unit and spends one; a cancelled search, a
  disconnect, a save or load that completes during the wait, a save still
  running at the end, stepping off the tile, a roof built over it and the ground
  being replaced all spend nothing and pay nothing;
- two searchers on the last unit: the one who finishes first is paid, the
  other gets nothing and the patch reads 0;
- an exhausted patch refuses before the 30-second wait starts;
- the record survives a production disk round trip (`BuildVarDirectory` and
  `Load_Entry`) both partly spent and fully exhausted, so a reload never refills
  a patch; duplicate, negative and fractional records fail closed;
- maps without Persistence or `foraging_enabled` neither search nor create records.

Old saves have no records, so every patch starts full; a fresh world starts with
none. Moving maps, shard transit and train transfer do not carry records: they
describe a fixed coordinate on one level.

Not covered natively: the real client wait bar, and a full-world save/load
through the save operation (the record is an ordinary saved `/obj`).

## Phase 3: search panel

`Forage nearby` opens a small window instead of starting a search straight away.
It shows the habitat (climate, ground, season), how much the 8x8 patch has left
in words (untouched, plenty left, some left, almost bare, picked clean), the
expected search time, and one button per focus: Anything, Stones, Sticks, Wild
seeds, Mushrooms. Foci this ground cannot give are greyed out, and an empty
patch offers no button. The hidden `Forage For` verb (`forage-for seeds`) is the
classic fallback and macro target. Nothing is created per tick, no HUD element
is added and nothing about other players' searches is shown beyond the shared
patch stock. Find indicators were left out: they would need per-client images
and give little over the panel.

## Phase 4: biome, season and skill

Each focus is a small table in `foraging.dm`; every find is one item from an
existing gathering path and still costs exactly one shared unit.

| Focus | Ground | Climate and season | Find |
| --- | --- | --- | --- |
| Stones | grass, dirt, beach, desert sand | any | 1 stone |
| Sticks | grass, dirt | not desert | 1 small wood piece |
| Wild seeds | grass, dirt | the crop's own biomes; not winter | 1 seed of a wild crop (wheat, oat, barley, rice, turnip, potato, beans, flax, cotton, parsley, celery, chamomile, dandelion, mint, sunflower, rose) |
| Mushrooms | grass, dirt | the mushroom crop's biomes; not winter or dry season | 1 bunch of edible mushrooms |

Anything picks a category weighted 3:3:2:2 among those the tile offers. The seed
list is a subset of the wild crops flora regrowth already plants, so no research
gate is bypassed. Berries are never found: they keep their own smell-based
identification. Psilocybin mushrooms, herbs and ores are excluded.

Farming skill shortens a search (30 s divided by the farming coefficient, capped
at 1.5) and darkness lengthens it by half; the time is clamped to 20-45 s. A
find gives one point of farming practice. Skill never changes the amount.

## Phase 5: renewal

Each record also stores `renew_from`, the renewal clock reading when the next
unit started growing back. One unit returns per hour of active server time,
up to the full four. Nothing is banked: when a patch reaches full stock its
stamp clears, and the next find starts a fresh hour.

- **Clock policy.** The clock is the durable active-server clock behind the round
  timer (`roundduration2text_in_ticks`). The world save stores it and a load
  restores it, so server downtime grows nothing and a reboot's `world.time`
  reset changes nothing.
- **Lazy, no workers.** Stock is worked out when someone opens the panel or
  finishes a search. There is no timer, process or scan per patch.
- **Safe failure.** A clock reading behind the stamp (a legacy save without its
  round clock, or a clock moved back) restamps without granting anything. A
  record saved before renewal existed starts its clock the first time someone
  looks at it, never while a save is running. A text or negative stamp fails
  closed like a bad stock count.
- **Never refills:** login, reconnect, terrain change, season change, focus change,
  or anything other than elapsed active time.

The probe checks each of these, including a disk round trip of the stamp.

## Phase 6: balance and rollout

Numbers from source, per player:

| Activity | Time | Yield |
| --- | --- | --- |
| Foraging, fresh patch | 20-45 s per search | 1 stone, stick, seed or mushroom; 4 per 8x8 patch, then 1 per hour |
| Mining one rock tile | one dig | 16-24 stone |
| Small bush seeds (knife) | instant, then 10 min per bush | one seed stack |
| Wild crop (flora regrowth) | one harvest | a crop's normal produce and seeds |

Foraging stays a trickle beside mining and harvesting. A forager working fresh
ground manages about two finds a minute at most, and must keep walking: a patch
is 64 tiles and holds four. Inside a settled 50x50 area (about 40 patches) the
shared stock is about 160 finds, then about 40 an hour for everyone together.
Mushrooms are the only food (satisfaction 4, a snack) and are seasonal.

Cost: one look touches two turfs' contents (each capped at 64). 20,000 looks in
the native probe took about 0.05 s on the cloud runner. Records exist only for
patches someone has searched; a 500x350 level has at most 2,772.

Rollout: on for Persistence worlds since phase 1. No other map is switched on;
a round map opts in with `foraging_enabled = TRUE` after its own review.

## Next phases and acceptance gates

1. **Storage and economy.** Done; see Phase 2 above.
2. **Player search UX.** Done; see Phase 3 above.
3. **Biome/season tables.** Done; see Phase 4 above.
4. **Renewal.** Done; see Phase 5 above.
5. **Balance and rollout.** Done; see Phase 6 above. Possible later work: player
   find indicators, more categories (fibre, flint) after their own audit, and
   anonymous counters if live yields need checking.

## Evidence and honest limits

`python3 tests/foraging/test_contract.py` checks seven offline source/projection
contracts. It does not execute DM or prove persistence. `tests/foraging/probe.dm`
exercises production helpers in the existing ecology constructor fixture; its
command and permission requirements are in `tests/foraging/README.md`.

The probe passes at the repository pin (516.1688) on Linux through
`tests/ecology_spawning/run_linux.py`.
