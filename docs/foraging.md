# Active foraging: design and experimental phase one

## Goal and boundaries

Give explorers a deliberate way to search outdoor terrain for small overlooked
resources, inspired by Project Zomboid's exploration loop, not its code, UI or
assets. Civ13's existing bushes, wild crops, trees, mining, sifting and hunting
remain the primary resource systems. Foraging must not become a source of free
high-tier materials or a way around research.

This is phase one, not a finished PZ search-mode replica. It is on for
Persistence worlds and off elsewhere unless a map opts in.

## Phase 1: bounded search and shared scarcity (this draft)

- `Forage nearby` in Crafting searches the tile under the player.
  It is on wherever Persistence is on (Val, 2026-11-10). Other maps opt in through `foraging_enabled`, which is false by default.
- Search takes 30 uninterrupted seconds. Existing `do_after` cancels movement,
  active-hand changes and incapacity and prevents repeated actions. Revalidate
  connection, map policy, exact turf, habitat and persistence epoch on completion.
- Open grass/dirt yield one stone or small wood piece; ordinary beach/desert sand
  yield one stone. Caves, snow, farmland, water, roofs, dense/structured/covered
  tiles and invalid outdoor climates are excluded. Food identification and rare
  loot are deliberately absent until researched and balanced.
- A fixed 8x8 coordinate patch shares four units across all players and categories.
  A successful completion spends one before rolling. No preview, XP, bonus yield,
  individual player cache or automatic regeneration. Traversing a boundary accesses
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

The verb currently remains visible when disabled and explains that fact. A later
UI integration should hide it or offer a discoverable search toggle without
adding more permanent HUD clutter. No client overlays or new art are included.

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

## Next phases and acceptance gates

1. **Storage and economy.** Done; see Phase 2 above.
2. **Player search UX.** A modern search panel and classic fallback with current
   habitat, coarse abundance and cancel state; optional player-only find indicators,
   focus categories and controller/key binding. Indicators must not leak others'
   discoveries, create shared objects every tick or bypass movement interruption.
3. **Biome/season tables.** Data-driven weighted categories using current ecology
   ground/climate and actual seasons. Expand to safe existing food/material paths
   only after auditing their acquisition and research gates. Identification of risky
   food, lighting/weather perception and farming skill affect search quality/speed,
   not extra unaccounted stock. No broad copy of another game's loot tables.
4. **Renewal.** Add durable lazy deadlines, explicit time policy and caps. Test clock
   changes, downtime and restart before enabling recovery. Never regenerate on login,
   world.time reset, changing ground/category, or re-creating an index. Preserve
   depletion across migrations and avoid a background timer per patch.
5. **Balance and rollout.** Measure discovery rate against bush harvest, mining and
   sifting; instrument anonymous counters, bound per-client work, test large maps,
   then propose a separately reviewed map opt-in. User confirmation for live changes.

## Evidence and honest limits

`python3 tests/foraging/test_contract.py` checks seven offline source/projection
contracts. It does not execute DM or prove persistence. `tests/foraging/probe.dm`
exercises production helpers in the existing ecology constructor fixture; its
command and permission requirements are in `tests/foraging/README.md`.

The probe passes at the repository pin (516.1688) on Linux through
`tests/ecology_spawning/run_linux.py`.
