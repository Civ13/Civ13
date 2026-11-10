# Active foraging: design and experimental phase one

## Goal and boundaries

Give explorers a deliberate way to search outdoor terrain for small overlooked
resources, inspired by Project Zomboid's exploration loop, not its code, UI or
assets. Civ13's existing bushes, wild crops, trees, mining, sifting and hunting
remain the primary resource systems. Foraging must not become a source of free
high-tier materials or a way around research.

This draft implements a **disabled-by-default prototype**, not a finished PZ
search-mode replica. No map is opted in. No live server, save, launcher or client
configuration is changed. Merge, activation and live testing are separate steps.

## Phase 1: bounded search and shared scarcity (this draft)

- `Forage nearby (experimental)` in Crafting searches the tile under the player.
  A map author can opt in through `foraging_enabled`; initial false everywhere.
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

## Next phases and acceptance gates

1. **Prove storage and economy before activation.** Compile at the repo's BYOND pin;
   execute native probe and full save/load round trip; test simultaneous last-unit
   completion, canceled waits, load admitted/completed mid-wait, same-level reload,
   patch-origin terrain replacement, roofs, explosion/fire, relog and reconnect.
   Confirm old saves have no records and reset worlds have none. Audit world-clearing
   and transit/shard behavior; prototype is not approved for moving-map activation.
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

Initial cloud compiler setup attempted `bash scripts/cloud_byond_setup.sh` but
failed at `sudo: command not found`. Thus the native probe and gameplay/save-load
roundtrip are **not run** here. Keep the PR draft and feature disabled until the
required acceptance evidence exists. A source review is not deployment evidence.
