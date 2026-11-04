# Modern factory automation: audit and phased design

Status: **design proposal; nothing here is implemented or activated.** Merging
this document does not approve any phase. Each phase below starts only after
Val picks a direction, and each lands as its own PR with its own tests.

Source pin: master `2181750c74d2a97d52ceb0063a663a63898395fb` (after #3601
stamp mill, #3603 renewables and #3607 moving saves). Line numbers below refer
to that revision.

## Goal

Modern-era settlements (Gaia and other persistent Nomads maps with research)
should be able to scale production by building it, not by clicking more: lay
belts, place transfer arms between belts, crates and machines, and let powered
machines turn raw resources into components and finished goods while players
expand, defend and maintain the works.

This is Civ13's own design. It reuses Civ13's cable grid, research tree,
material recipe catalog, machine sprites and persistence model, and it keeps
Civ13's identity: physical items with material, quality and condition; power
that comes from fuel, weather and reactors; factories that can be raided,
sabotaged and need upkeep. It does not copy any other game's rules, names,
numbers, recipes or art.

## What exists today

### Belts and switches

[`code/modules/1713/machinery/conveyor2.dm`](https://github.com/Civ13/Civ13/blob/2181750c74d2a97d52ceb0063a663a63898395fb/code/modules/1713/machinery/conveyor2.dm)
holds the only working belt, `/obj/machinery/conveyor`, and its switch.

- Each belt tile is in `processing_objects` and runs on the 2-second `obj`
  process. Every call allocates `loc.contents - src`, then `spawn(1)` steps up
  to 10 unanchored movables one tile with `step()`. Throughput is at most one
  tile per 2 seconds, i.e. 0.5 tiles/s, with no spacing, lanes or back-pressure.
- Belts move anything loose, including mobs, through ordinary `Move()`, so
  every step runs turf `Entered`/`Exited`, crossing and lighting hooks.
- Belts draw no power (`powerneeded` is unset). Anyone with a crowbar can lift a
  belt. Corners exist; the file notes "no diverters".
- A switch links belts by a random text `id`; it rescans all of
  `processing_objects` on every toggle and caches a non-`tmp` `conveyors` list.
- Recipes: `conveyor belt` and `conveyor switch`, 5 steel each, era 8, gated by
  the `assembly_line` research node
  (`config/crafting/material_recipes_global.txt` lines 1883-1884,
  `research_node.dm` lines 430-431).
- Only `maps/1969/pepelsibirsk.dmm` maps belts. `tests/conveyor/` covers the
  snapshot regression, cargo movement and the ten-item cap.

[`code/modules/1713/automation.dm`](https://github.com/Civ13/Civ13/blob/2181750c74d2a97d52ceb0063a663a63898395fb/code/modules/1713/automation.dm)
is a commented-out powered `/obj/structure/conveyer` stub.

`icons/obj/recycling.dmi` already ships unused `diverter*`, `grinder-*` and
`separator-*` states. `icons/obj/modern_structures.dmi` has `loader`,
`unloader` and `stacker` states used by the company assembler.

### Company assembler

`/obj/structure/assembler` (`computers_objects.dm` lines 465-575) is a fixed
three-tile loader -> processor -> unloader line for the four company factions.
It takes one precursor stack by hand, hides it at `locate(1,1,1)`, and uses
`spawn(20)`/`spawn(500)` chains to emit components. It is faction-locked, not
connected to belts, not powered and not save-safe mid-run. It is a useful
sprite and concept source, not a base to extend.

### Power

- `/obj/structure/cable` (`cables.dm`) forms connected components. Consumers
  call `draw_cable_power()` -> `rebuild_supply(requester, request)`, which
  walks the **whole component** (breadth-first over every cable, engine,
  generator and battery) on every call and publishes demand/capacity to every
  cable. Reservations are keyed by consumer, so repeated calls are idempotent.
- Sources: combustion engines (`engines/`, 25-500 PU), batteries, and the
  `civ_generator` registry settled once per second by
  `code/processes/civ_generation.dm` (solar array 30 PU, photovoltaic panel
  10 PU from age 7, wind charger 12 PU from age 5, wind turbine 45 PU from age
  8, nuclear reactor). The registry is capped at 128 sources.
- Generator output expires after one second and is never backfilled; runtime
  wiring and ledgers are excluded from saves (`docs/modern-energy-implementation.md`).

### Powered production machines

| Machine | Path | Input | Output | Power |
| --- | --- | --- | --- | --- |
| Industrial drill | `/obj/structure/drill` (`modern_items.dm` 1024) | none, dirt on z1 | 2 ore / 2 min onto its tile | 150 |
| Fracking rig | `/obj/structure/drill/fracking` | site | oil | 300 |
| Soil sifter / river concentrator | `/obj/structure/drill/sifter[/panner]` | site | trace ore onto tile | 150 |
| Stamp mill (#3601) | `/obj/structure/drill/stamp_mill` (`stone_crushing.dm` 124) | 50-stone hopper, loaded by hand | 1 stone / 4 s rolled to sand/ore onto tile | 150 |
| Powered sawmill | `/obj/structure/sawmill/powered` (`production.dm` 2285) | logs by hand | planks | 1 |
| Centrifuge, grinder | `Chemistry-Machinery.dm` | by hand | reagents | yes |

Unpowered processors that a factory would want to feed: bloomery, blast furnace
and kilns (`blacksmithing/refining.dm`), refinery, loom, grain mill, canner,
printing press, dehydrator, compost, tablet press, oil well.

Shared facts across these machines:

- Input logic lives in `attackby(obj/item/I, mob/living/human/H)` and assumes a
  human: skill checks, `to_chat`, `do_after`, `drop_from_inventory`. Nothing
  can hand a machine an item without a mob.
- Output goes to the machine's own tile through
  `turf.deposit_small_resource()` (stack-merging, capped at 12 stacks), or
  `new` at `loc`. There is no output buffer or facing.
- Each machine runs its own `spawn(2 SECONDS)` loop guarded by
  `process_pending`. The drill family stops on `before_save()` and stays off
  after load.

### Recipes, research and eras

- Hand crafting reads `RECIPE:` lines from `config/crafting/material_recipes_*.txt`
  (material, name, result path, cost, time, ..., age). The Crafting Atlas and
  `scripts/atlas/` already model recipes, processors and resource sources, so a
  machine recipe can be shown in the Atlas without new tooling.
- Research gates recipes through `recipe_node_requirements`. The industrial
  branch already reads like a factory progression: `factories` (tier 4) ->
  `assembly_line` (5) -> `automation` (7) -> `digital_computing` (8, an
  era-changing prototype), with `electricity` (5) and `power_tools` (6) beside
  it. `assembly_line` and `automation` currently unlock only a handful of
  consumer goods.
- Era is global (`map.ordinal_age`) and advances when a faction completes a
  prototype capstone.

### Persistence

- `/obj/machinery` is not `/obj/item` or `/obj/structure`, so the generic saver
  writes only `map_storage_saved_vars`
  (`density;icon_state;dir;name;pixel_x;pixel_y;id`, `persistence/functions.dm`
  lines 144-163 and 298).
- Load constructs `new type(starting_loc)` and applies saved vars afterwards
  (`persistence/loading.dm` line 254).

## Gaps for automated production

1. **No mob-free item interface.** Machines only accept items from a human's
   hand and only emit to their floor. This is the single largest blocker.
2. **No transfer device.** Nothing picks an item from a belt, crate or machine
   and puts it into another. The company loader is a hand-fed sprite.
3. **Belts are too slow and too expensive per tile.** One `Move()` per item per
   tile, 0.5 tiles/s, a list allocation per belt per tick, `spawn()` inside
   `process()`, and no idle sleep. They also push mobs, which turns a factory
   into a grinder for players.
4. **No routing.** No splitters, filters, merges, crossings or sorting gates.
5. **No general machine recipes.** Every machine hard-codes its own products;
   there is no powered fabricator that turns components into goods.
6. **Power does not scale with consumer count.** Each consumer check walks the
   whole grid. A factory of 200 consumers on a 2,000-cable grid checking every
   2 seconds is about 200,000 node visits per second before any production work.
7. **Belts do not survive a reload correctly** (see the next section).
8. **No observability.** No throughput, stall reason or power shortfall view for
   a production line; the only feedback is `examine` text.

## Defects found in the existing belt (independent of new features)

These are small and worth fixing first whatever direction is chosen.

- **Saved belts can reverse or turn after load.** `New(loc, newdir, on)`
  computes `forwards`/`backwards` from `dir` in the constructor. Load calls
  `new type(loc)` with no `newdir`, so the constructor sees the default `dir`
  (south) and the saved `dir` is applied afterwards. A loaded east-facing belt
  then carries cargo south when switched on. Corner belts are worse. There is
  no `after_load()` to recompute directions.
- **Switch state is inconsistent after load.** The switch saves `icon_state`
  but not `position`, so it can show "forward" while every belt is stopped.
  Belts also do not save `operating`.
- **Switch rescans every processing object on each toggle** to find its belts.
  That is cheap with 45 mapped belts but should become a registry if belts
  scale.
- **Belts move mobs** and run unpowered, which is fine for a 1969 map prop but
  not for player-built industry.

## Design

### Principles

- **Physical items stay physical.** Items keep their material, quality,
  condition and reagents end to end. No item becomes an abstract count, so a
  raid on a crate or belt yields the real goods.
- **Render what can be interacted with.** Items on belts stay visible and
  clickable while a player is in range. Performance work must not hide them.
- **Lines, not tiles.** The unit of simulation is a belt line (a run of
  connected belt tiles), ticked once, not each tile.
- **Sleep when nothing changes.** Empty, blocked or unpowered lines and idle
  arms unregister and are woken by an event (item added, space freed, power
  restored).
- **No offline production.** Save, restart and lag never pay out missed work,
  matching the energy and drill contracts.
- **Mob-free core, mob-facing shell.** Every machine gets a mob-free
  accept/offer API; `attackby` becomes a thin wrapper around it.

### 1. Machine ports (the foundation)

Add a small interface on `/obj`, default "no port":

- `factory_accepts(obj/item/I, from_dir)` returns how much of `I` the machine
  would take now (0 for none), without side effects.
- `factory_insert(obj/item/I, from_dir)` takes up to that much, splitting stacks
  through the normal stack API, and returns the amount taken.
- `factory_offer(to_dir, filter)` returns the next output item a transfer device
  may take, and `factory_take(obj/item/I, to_dir)` removes it.
- `factory_wake()` lets the machine restart when inputs arrive.

Machines gain an output buffer in their own `contents` (bounded, saved like the
stamp mill hopper) instead of only spilling onto the floor. Existing
floor output stays the default when no arm takes from the buffer, so manual
play is unchanged.

Crates and closets get the port for free (accept anything that fits, offer
anything). A new **storage bin** offers only a chosen item type.

Retrofit order: stamp mill (already has a hopper), drill/sifter (output only),
powered sawmill, bloomery/blast furnace and kilns, grinder/centrifuge,
canner, then the rest. Skill, faction and safety checks that today read the
human move to the device that configured the machine (see "Ownership").

### 2. Belt lines

New buildable belts (keep the old type for the mapped 1969 prop, but fix its
load defect):

- A belt tile holds up to **4 item slots** in its own `contents`. Items on a
  belt are not on the turf, so moving them does not run turf `Entered`/crossing
  hooks, abandoned-debris aging, or lighting updates.
- Visibility: the belt shows its items through `vis_contents` with
  per-slot pixel offsets and an `animate()` glide between slots, so motion looks
  continuous without real movement. Clicking an item on a belt must pick it up
  normally; that needs a pickup path for items whose `loc` is a belt (risk R3).
- A `/datum/belt_line` owns an ordered list of tiles from a source end to a
  sink end. Topology changes (build, remove, rotate) mark the line dirty and it
  rebuilds lazily.
- A dedicated factory process ticks active lines at 0.5 s with a per-tick
  budget (`PROCESS_TICK_CHECK`), shifting slot indices forward when the next
  slot is free. Target speed: 2 tiles/s for the basic belt, 4 tiles/s for a
  later fast belt. A full or empty line costs nothing until woken.
- At the sink end the line hands its front item to whatever port is in front
  (another line, a machine, a crate) through `factory_insert`; if nothing takes
  it, the line backs up and sleeps.
- Belts carry items, never mobs. A mob on a belt tile is not moved; dropping an
  item onto a belt places it into a free slot.
- Belts draw power per line (for example 1 PU per 4 tiles, rounded up), so a
  generator, cable and belt all have to be built and maintained.
- Underground crossings ("belt tunnel", pair up to 4 tiles apart) and a merge
  rule (side-loading onto a line inserts into the next free slot) come with
  routing in phase 2.

### 3. Transfer arms

A powered, anchored arm that takes from the port behind it and inserts into the
port in front of it. Variants:

| Arm | Speed | Filter | Power | Unlock |
| --- | --- | --- | --- | --- |
| Feeder arm | 1 item / 2 s | none | 2 PU | `automation` |
| Sorting arm | 1 item / 2 s | one item type, set by hand | 3 PU | `automation` |
| Stack arm | up to 10 of one stack / 2 s | optional | 5 PU | `digital_computing` |

Arms only act when both sides answer `factory_accepts` with a positive amount,
then sleep until woken by either side. They never take from mobs.

### 4. Routing

- **Sorting gate** (reuses the `diverter*` states): on a belt line, sends items
  matching a filter to its side output and everything else straight on.
- **Splitter**: alternates between two outputs.
- **Belt tunnel** for crossings.
- Lines stay simple straight-and-corner chains; routing devices are the
  junctions between lines, which keeps each line an ordered list.

### 5. Fabricator

A powered machine that turns inputs into one selected output from a
**factory recipe list**. Two options for where those recipes come from are in
the decisions section. Common rules either way:

- The fabricator is configured once (recipe, by a player with the required
  research and Crafting skill), then runs from its input buffer without a mob.
- Each cycle reserves inputs, waits the recipe time while powered, then commits
  inputs and output in one step. Losing power pauses; it never half-consumes.
- Output quality uses a fixed factory quality for the recipe, not the
  configuring player's live skill, so goods are consistent and do not depend on
  who is online.
- Tiered fabricators (`assembly_line`, `automation`, `digital_computing`) unlock
  longer recipes and faster cycles.

### 6. Monitoring

A factory panel on the existing computer objects lists each line and machine in
range with state (running, starved, blocked, no power), items per minute over
the last few minutes, and power use. This doubles as the debug view for
performance tuning.

### Ownership and griefing

- Arms, gates and fabricators remember the faction of whoever configured them;
  only that faction (or someone who first breaks the lock with tools over time)
  can reconfigure.
- Removing a powered belt or machine needs it unpowered or a longer
  deconstruction action, so factories can be raided and sabotaged but not
  erased in one click.
- Goods on belts and in buffers are real loot; this is intentional.

## Performance plan

Budgets to design and benchmark against (per server, Gaia scale):

| Element | Design target | Ceiling for the benchmark |
| --- | ---: | ---: |
| Belt tiles | 2,000 | 5,000 |
| Items on belts | 8,000 | 20,000 |
| Arms | 300 | 1,000 |
| Fabricators and retrofitted machines | 100 | 300 |
| Powered consumers on one grid | 300 | 1,000 |

Risks and mitigations:

- **R1, grid walk per consumer.** Replace per-call `rebuild_supply()` walks with
  a cached component datum: rebuild only on topology change (cable, source or
  consumer added/removed/moved), settle supply/demand once per second next to
  `civ_generation`, and answer `draw_cable_power()` from the cache. Keep the
  current atomic reservation semantics and the existing negative controls.
- **R2, per-tile processing.** Belt lines tick per line with a budget and sleep
  when idle; belts leave `processing_objects`. Remove `spawn()` from belt
  processing.
- **R3, item location semantics.** Items inside a belt's `contents` change
  pickup, examine, hover names, throwing and decay rules. Each needs a probe;
  the abandoned-debris registry already treats arbitrary object locations as
  protected, which is acceptable for belt cargo.
- **R4, rendering cost.** `vis_contents` plus `animate()` is cheap per item but
  every moving item still sends appearance updates to nearby clients. Measure
  client FPS and server send volume with 1,000 visible moving items before
  committing to 4 slots per tile; fall back to 2 slots if needed.
- **R5, save size and duration.** 20,000 belt items add entries to the
  segmented level saves. Use the existing low-memory segmented format and
  measure with `tests/world_save`; consider merging same-type stacks in a slot
  before save.
- **R6, wake storms.** A long line unblocking wakes everything upstream. Wake
  only the immediate upstream neighbour; it wakes the next when it moves.

## Persistence plan

- Belts, arms, gates and fabricators become `/obj/structure` (full var save)
  with explicit `persistence_runtime_var` exclusions for line, cache, wake and
  timer fields, following the drill and sifter pattern.
- Items in belt slots, machine input and output buffers save as contents.
- Line datums, grid caches and sleep registrations are runtime-only and are
  rebuilt in `after_load()` once all tiles of a level exist.
- A running factory resumes after a restart when its saved intent was "on" and
  power is available, but saved elapsed time never produces goods.
- Native round-trip probes (moving-save harness) cover: belt directions, slot
  order, buffers, a fabricator mid-cycle (reserved inputs return to the input
  buffer), and a switch/arm configuration.

## Phased plan

Each phase is one or more PRs with offline probes in the style of
`tests/conveyor/` and `tests/stone_crushing/`, compiled against the pinned
BYOND, plus a native benchmark where noted.

| Phase | Scope | Exit check |
| --- | --- | --- |
| 0. Foundations | Fix belt load direction and switch state; cache power components (R1) behind the existing tests; add the port interface with crates and the stamp mill as first implementers. | Belt round-trip probe; grid benchmark shows consumer checks no longer scale with grid size; stamp mill accepts stone without a mob. |
| 1. Belts and arms | Belt lines with slots, line ticking and sleep; feeder and sorting arms; storage bin; drill, sifter and stamp mill output buffers; recipes and research gates. | Ore from a drill reaches a crate by belt and arm with no player action; 2,000-tile benchmark within budget; save/load round trip. |
| 2. Routing and smelting | Sorting gate, splitter, belt tunnel; ports for bloomery, blast furnace, kilns, powered sawmill and grinder. | Mixed ore line sorted into separate furnaces; ingots out by belt. |
| 3. Fabricators | Fabricator tiers and the chosen recipe source; Atlas shows factory recipes; stack arm. | A configured line produces one modern good from raw inputs unattended. |
| 4. Scale and logistics | Factory panel; fast belt; train and vehicle loading ports; balance pass with live data. | Panel shows throughput and stalls; benchmark at ceiling numbers. |

Phase 0 is useful even if the rest is reordered, and changes no gameplay
beyond fixing saved belts.

## Decisions for Val

1. **Starting slice.** Recommended: phase 0 then phase 1 (move resources
   automatically before adding fabricators). Alternative: phase 0 then a
   fabricator first, fed by hand and arms, with belts later.
2. **Fabricator recipe source.** Recommended: a curated factory recipe list
   (new config file, Atlas-visible) of intermediate parts and goods, so
   factories have their own production chains. Alternative: let fabricators run
   any existing hand recipe from the material catalog at its research gate,
   which is broader but reuses hand-balance numbers that assume a human.
3. **Belt cargo model.** Recommended: items held in belt slots (`contents`,
   rendered through `vis_contents`). Alternative: keep items on turfs and only
   batch their movement, which keeps pickup semantics but leaves the per-item
   `Move()` cost.
4. **Era gating.** Recommended: belts at `assembly_line` (as today), arms and
   routing at `automation`, fabricators at `digital_computing`. Alternative:
   open basic belts and feeder arms earlier at `factories` with steam power.

## Not in scope

- Fluid pipes and pumps (hydroponics records pumps as a later item; a fluid
  network would be a separate design).
- Robots, drones or automated combat.
- Changing hand-crafting balance or existing machines' outputs.
- Activating any of this on the live server; deployment stays Val's call.
