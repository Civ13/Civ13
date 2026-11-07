# Modern factory automation: audit and phased design

Status: **phases 0 to 4 implemented except the balance pass, which needs live data.** Val chose the first slice on 2026-11-04: phase 0, then
belts and transfer arms (phase 1), and asked threads to continue the phases.
The other open decisions below are still pending. Each later phase lands with
its own tests.

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

These are small and worth fixing first whatever direction is chosen. Phase 0
fixes the first two: belts rederive their directions in `after_load()` and save
`operating`, and switches save `position` and reapply it after load.

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
powered sawmill, bloomery/blast furnace, then canner and the rest. Phase 2
did the first four (`code/modules/1713/factory_machines.dm`). Clay kilns cast
into molds and the reagent grinder works on containers, so both stay manual
until a later phase gives them a reason to be automated. Skill, faction and safety checks that today read the
human move to the device that configured the machine (see "Ownership").

### 2. Belt lines

Phase 1 implements `/obj/structure/factory_belt` (`code/modules/1713/factory_belts.dm`);
the old mapped conveyor stays as it is for the 1969 map.

- **Cargo stays a floor item.** During implementation the slot-in-`contents`
  model turned out to need new rules for adjacency, pickup, hover and examine
  (risk R3). Phase 1 instead keeps cargo as ordinary items on the belt's turf,
  so pickup, rendering, saving and debris rules are unchanged. Belts move cargo
  with `persistence_set_loc()` (a raw location write that respects save
  capture), so no turf `Entered` or crossing hooks run per step. Items that emit
  light use `forceMove()` so their light follows. This is decision 3's
  alternative, chosen because it avoids R3 entirely; it can still be revisited.
- A belt tile tracks up to **4 slots** along its direction; slot position is
  shown as a pixel offset (-12, -4, 4, 12) with one `animate()` glide per item
  per step. A reloaded belt adopts saved cargo into the slot nearest its saved
  pixel offset.
- The `factory belts` process steps active belts once a second with the
  scheduler's tick budget (`PROCESS_TICK_CHECK`, resuming next tick when over
  budget). Items advance up to 8 slots a step: 2 tiles a second.
- Belts are per tile rather than line datums: each belt hands its exit item to
  the tile in front. That is a belt not facing back (from behind it enters at
  the first slot, from a side partway along, so corners and side-loading work),
  or any factory port that accepts it. If nothing takes it the belt backs up.
- Empty belts leave the process; dropping or handing on an item wakes them.
  A blocked belt retries every 2 steps, and a belt that frees space wakes the
  belts feeding it.
- Belts carry items, never mobs. A wrench turns a belt; a crowbar lifts it.
- **Power:** a belt runs only while a powered **belt drive** is within the
  drive's range (7 tiles, `code/modules/1713/factory_routing.dm`). One drive
  takes one cable connection and 4 PU however many belts it runs, so a line
  needs no cable under each tile. A belt caches the drive that last ran it and
  only searches the (short) list of powered drives when that one stops; an
  unpowered belt sleeps, and a drive that gains power wakes the belts in its
  range. Drives step before belts each second.
- Benchmark (fixture, 516.1688 DEBUG build): 1,922 belts with 2,356 moving
  items cost about 60 ms per step while everything flows, i.e. about 6% of
  one core at one step a second, and less once queues settle. Idle belts cost
  nothing.
- Sorting gates, splitters and tunnels are belt subtypes that only change
  where the exit item goes (see "Routing").

### 3. Transfer arms

A powered, anchored arm that takes from the port behind it and inserts into the
port in front of it. Variants:

| Arm | Speed | Filter | Power | Unlock |
| --- | --- | --- | --- | --- |
| Feeder arm | 1 item / 2 s | none | 2 PU | `automation` |
| Sorting arm | 1 item / 2 s | one item type, set by hand | 3 PU | `automation` |
| Stack arm (phase 3b) | up to 10 items of one kind / 2 s | optional | 5 PU | `digital_computing` |

Phase 1 implements the feeder and sorting arms (`code/modules/1713/factory_arms.dm`).
An arm takes from a port behind it (belt exit, crate, parts bin, or the output
stacks on a drill, sifter or stamp mill tile) or a loose floor item, and only
lifts an item it can set down in front: into a port, or onto a clear floor of
fewer than 12 items. A partial insert (a nearly full stamp mill hopper) keeps
the rest held for the next swing. While it is off, the Rotate verbs turn an
arm and a wrench fastens or unfastens it, like the other factory machines and
fluid parts; unfastened parts do no work. A
direction arrow overlay shows where it sends items. A running arm saves its
switch and resumes after a reload; stored time never pays out a swing.

Every arm lifts a whole stack as one item. The stack arm (phase 3b) lifts up
to ten items each swing, all of the exact type it took first (or of its filter,
when one is set), so it clears crates of loose single stacks and finished goods
ten times faster. Its Clear Filter verb lets it move anything.

The **parts bin** (`/obj/structure/closet/crate/factory_bin`, steel, Assembly
Line) is a crate that only accepts more of what it already holds.

Arms only act when both sides answer `factory_accepts` with a positive amount,
then sleep until woken by either side. They never take from mobs.

### 4. Routing

Phase 2 implements these as belt subtypes in
`code/modules/1713/factory_routing.dm`; each carries and saves like a belt and
overrides only which outputs it tries for its exit item. The side output
starts on the right and a screwdriver swaps it; an arrow overlay shows it.

- **Sorting gate** (`diverter1` overlay): sends items matching its filter to
  the side and everything else straight on; with no filter everything goes
  straight on. The Set Gate Filter verb takes the held item's type, because
  hitting a belt with an item drops it onto the belt.
- **Splitter** (`diverter0` overlay): alternates straight and side, and uses
  the other output when one is blocked, so a full branch never stops the line.
- **Belt tunnel**: an entrance hands its exit item to the first tunnel exit
  facing the same way up to 6 tiles ahead, under whatever lies between; an
  exit that frees space wakes its entrance.
- Lines stay simple straight-and-corner chains; routing devices are the
  junctions between lines, which keeps each line an ordered list.

### 5. Fabricator

A powered machine that turns inputs into one selected output from a
**factory recipe list**. Val chose a curated list (decision 2), implemented in
phase 3a as `config/crafting/factory_recipes.txt` and
`code/modules/1713/factory_fabricators.dm`. Each `FACTORY:` row gives a name,
output path and amount, inputs (`path=amount;...`), cycle time at tier 1,
minimum fabricator tier and research node. Invalid or duplicate rows are
skipped and listed in `factory_recipe_errors`; the Atlas shows the rows as
"Factory fabricator" recipes. Hand crafting is unchanged.

As built: a person sets the recipe by hand from the recipes their faction has
researched and the fabricator's tier allows (research only; no Crafting skill
check). It buffers two cycles of each input from arms and belts, needs cable
power for every one-second step of a cycle, and spends inputs only when the
cycle completes, leaving output on its own tile and waiting once twelve items
lie there. Changing the recipe or removing the machine drops the buffer. The
recipe and progress are saved. Tiers: assembly fabricator (`assembly_line`,
6 PU, full time), automated fabricator (`automation`, 10 PU, 0.75 time) and
computerized fabricator (`digital_computing`, 15 PU, half time). Outputs are
plain material stacks, so there is no quality to fix yet. Rules from the
design:

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

As built (phase 4b): the **factory monitor** (`/obj/structure/factory_monitor`,
5 electronics, Automation, `code/modules/1713/factory_monitor.dm`) is a
terminal of its own rather than an OS program. Using it opens a table of every
arm, fabricator and belt drive within seven tiles, with offsets from the
monitor, state and items per minute, plus one summary row for belts (how many,
how many carry items, how many are blocked). Arm states are off, no power,
waiting (nothing to move), blocked (holding an item with nowhere to put it) and
running; fabricator states are no recipe, starved, blocked (output tile full),
no power and running, with the recipe and cycle progress. Arms count items
moved and fabricators count items made in a two-minute window of one-minute
buckets (`/datum/factory_rate`). Counters and states are runtime only and cost
one addition per transfer; the monitor scans only when someone looks. Each row
also shows the power units the machine has reserved on its grid right now
(belts draw through their drive), and the page totals them and shows each
grid's use against its capacity, counting everything on that grid.

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

- **R1, grid walk per consumer.** Phase 0 lets `draw_cable_power()` reuse
  the last traversal's published totals when the consumer already holds the
  same reservation, the traversal is under a second old, and the component was
  within capacity. Sources (generators, batteries, engines) and topology
  changes already traverse at least once a second, so a grid with many
  consumers does about one walk per second instead of one per consumer check.
  Anything else, including an overloaded or unpowered component, still takes
  the full atomic traversal. The fast path also refuses as soon as an engine
  that powered the last traversal stops, because several engine paths set
  `on = FALSE` without notifying the grid. A topology change made by a raw `connections`
  edit without a traversal can be seen up to one second late. A cached
  component datum with explicit invalidation remains an option if the phase 1
  benchmark needs it; it would have to cover the 81 direct `connections`
  mutation sites first.
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
| 0. Foundations (done) | Fix belt load direction and switch state; reuse fresh reservations (R1); add the port interface (`code/modules/1713/factory_ports.dm`) with crates and the stamp mill as first implementers. | `tests/factory_automation/probe.dm`; the native grid probe's 20 repeated draws now take one traversal; stamp mill accepts stone without a mob. |
| 1. Belts and arms (done) | Belts with slots, per-belt stepping and sleep; feeder and sorting arms; parts bin; drill, sifter and stamp mill output ports; recipes and research gates. | `tests/factory_automation/belts_probe.dm`: crate to belt to crate, corners, blocking, drill output into the mill; 1,922-belt benchmark above. A full disk save/load round trip is still unverified. |
| 2a. Belt power and routing (done) | Belt drives; sorting gate, splitter, belt tunnel; recipes (drive at Assembly Line, routing at Automation). | `tests/factory_automation/routing_probe.dm`: drive range, power loss and recovery, gate filtering, splitter alternation and overflow, tunnels under a crossing, save exclusions. |
| 2b. Smelting and wood ports (done) | Bloomery and blast furnace take ore and fuel and start a smelt once both are loaded; the powered saw mill gets a 20-log hopper and cuts one log into 12 planks a second while powered; both offer their output stacks on their tile. Clay kilns (mold casting) and the reagent grinder stay manual. | `tests/factory_automation/machines_probe.dm`: limits, refusals, automatic smelt start and restart, output offers, mill power, plank merging, hopper save and return. |
| 3a. Fabricators (done) | Three fabricator tiers on the curated factory recipe list (five starting recipes: rolled steel, barbwire, cable coil, electronic circuits, electronic components); Atlas shows factory recipes; research gates. | `tests/factory_automation/fabricators_probe.dm`: recipe parsing and rejection, tier and research filtering, buffer limits, no work without power, a full cycle, pause on power loss without losing inputs, sleep and wake, output offers and limit, save clamping, buffer return. |
| 3b. Stack arm and more recipes (done) | Stack arm (`digital_computing`); factory recipes for bronze, glass and metal rods (eight in all). | `fabricators_probe.dm`: ten-item batches of one kind, no mixed batches, filter, feeder and sorting arms unchanged; recipe counts and tier lists. A complete unattended line in game is still unverified. |
| 4a. Fast belt and wagon loading (done) | Val chose this first on 2026-11-04. Fast belt (`/obj/structure/factory_belt/fast`, steel, Automation) takes a second belt step each tick, after every belt has taken its first, so cargo crosses two tiles a second and hands on to plain belts. Train wagons (`/obj/structure/trains/storage`: mining cart, tender, transport wagon) and shopping carts get storage ports: arms load and unload them within the same slot, size and item-type limits as a person (`code/modules/1713/factory_logistics.dm`). Modular vehicles have no item storage, so they have no port. | `tests/factory_automation/logistics_probe.dm`: fast line arrives in half the steps, fast-to-plain hand-off, fast list sleep, recipe gate; wagon load, capacity, unload, filters, tender fuel limit, cart load and unload. |
| 4b. Factory monitor (done) | Factory monitor terminal, arm and fabricator states and items-per-minute counters. | `logistics_probe.dm`: rate buckets roll and decay; the monitor lists the loading arm with its state and eight items a minute, a starved fabricator with its recipe, the drive and a belt summary; the page renders; Automation gate. |
| 4d. More recipes (done) | Val chose more factory recipes on 2026-11-05: rifle and pistol casings, iron bullets, ammo clips, stone bricks, wrench, screwdriver, claw hammer and wirecutters (tier 1, Assembly Line) and the 100-round ammo belt (tier 2, Automation), at the hand-crafting ratios; eighteen recipes in all. Finished cartridges stay manual because they need gunpowder, a reagent fabricators do not take. | `fabricators_probe.dm`: recipe counts and tier lists, a screwdriver item and a stack of three rifle casings made by a fabricator. |
| 4e. 3D printer (done) | Digital Age (2026) tier 4 fabricator, `/obj/structure/factory_fabricator/printer`, behind the era-9 `additive_manufacturing` node. It runs only the twelve tier 4 printing rows (plastic tools, containers, medical disposables, hardhat, gas mask, traffic cone) and also takes feedstock by hand, so it works without belts. Thirty recipes in all. | `fabricators_probe.dm`: research gate, printing-only recipe list, older tiers excluded, plastic buffering and a powered print. |
| 4c. Balance pass | Tune speeds, buffer sizes and recipe ratios from live server data; benchmark at ceiling numbers. | Needs factories built by players on the live server. |

Phase 0 is useful even if the rest is reordered, and changes no gameplay
beyond fixing saved belts.

## Decisions for Val

1. **Starting slice.** Decided 2026-11-04: phase 0, then phase 1 (belts and
   transfer arms) before fabricators.
2. **Fabricator recipe source.** Decided 2026-11-04: the curated list.
   Recommended was: a curated factory recipe list
   (new config file, Atlas-visible) of intermediate parts and goods, so
   factories have their own production chains. Alternative: let fabricators run
   any existing hand recipe from the material catalog at its research gate,
   which is broader but reuses hand-balance numbers that assume a human.
3. **Belt cargo model.** Phase 1 keeps cargo as floor items moved by raw
   location writes (see "Belt lines"), which avoids both the `contents`
   pickup problems and the per-item `Move()` cost. Open for Val to revisit.
4. **Era gating.** Recommended: belts at `assembly_line` (as today), arms and
   routing at `automation`, fabricators at `digital_computing`. Alternative:
   open basic belts and feeder arms earlier at `factories` with steam power.

## Not in scope

- Fluid pipes and pumps (hydroponics records pumps as a later item; a fluid
  network would be a separate design).
- Robots, drones or automated combat.
- Changing hand-crafting balance or existing machines' outputs.
- Activating any of this on the live server; deployment stays Val's call.
