# Automated chemistry: design and phased plan

Civ13 chemistry is hand-driven: every transfer is a person pouring one
container into another. This plan automates it in the same style as the
factory belts and arms ([factory automation](factory-automation-design.md)):
barrels ride belts first, then pipe networks link tanks and machines, and an
inert reaction vessel runs one chosen recipe. Val accepted the recommended
option for every decision below on 2026-11-04.

## What other codebases do

- **/tg/station plumbing** (inherited by Beestation, Monkestation, Nova Sector
  and others) is the only mature system. Ducts join machines into a network;
  demand ports pull up to 10 units every 2 seconds from supply ports,
  round-robin. Ducts hold nothing; tanks and machines do. Its mixing chamber
  lets in only a configured list of reagents, holds them unreactive, then
  reacts and empties before refilling. Code is AGPL v3 (art CC BY-SA 3.0), so
  it is legally reusable with credit, but it needs components, signals, tgui,
  reagent temperature and pH, which Civ13 lacks. We reuse the design and write
  Civ13-style code.
- **/tg/ synthesizers** make reagents from power alone. Beestation later made
  each consume a matter cartridge. Civ13 does not build them.
- **Goonstation's ChemiCompiler** is a programmable 10-beaker machine. Goon is
  CC BY-NC-SA 3.0, which is incompatible with AGPL: no code or art from it.
- **Nova Sector liquids and Nebula fluids** flood turfs. Not automation; only
  pipe-leak spills might borrow the idea later.

## Principles

- Every unit comes from a real source (well, spring, crop, ore, dispenser
  stock). Nothing creates chemicals from power.
- Storage and transport are inert; reactions happen only where a player chose
  a recipe, as at the reaction bench.
- The factory automation rules apply: mob-free ports, sleep when idle, no
  offline production, physical goods are real loot.

## Phased plan

| Phase | Scope | Research gate |
| --- | --- | --- |
| 0. Container ports (done) | Barrel ports on the oil well, petroleum and biofuel refineries and internal combustion engines; barrel station; reagent gate. | Machines keep their gates; station at Factories; reagent gate at Automation |
| 1. Pipes and tanks (done) | Pipes that hold no reagents, valves, powered pumps, inert holding tanks; one process stepping awake networks every 2 seconds; intakes with allowed-reagent lists; water intake; oil well and refinery outputs; engine fuel feed. | Factories |
| 2. Reaction vessel (done) | Inert vessel that pulls one chosen recipe's reagents in ratio for a batch, reacts only a full batch, pushes product out and sends leftovers to a waste output. Starts with the reaction bench's recipes. | Factories and Apothecary |
| 3. Packaging and tiers (done) | Bottler and automated tablet press fed by belts; faster vessel tiers; piped reagents as fabricator inputs. | Pharmacology, Automation, Digital Computing |
| 4. Monitoring and hazards | Network rows on the factory panel; optional leak spills (decided after playtesting). | Automation |

## Phase 0 as built

`code/modules/1713/factory_chemistry.dm` adds factory ports (see
`factory_ports.dm`) so belts and arms move barrels between machines:

- **Oil well:** takes one barrel with room when it has none and starts
  extracting; offers it once full. Taking it stops extraction.
- **Refineries:** a barrel holding feedstock (petroleum; olive oil, fat oil or
  ethanol for the biofuel refinery) is drained into the refinery, ethanol at
  its purity as by hand. An emptied barrel becomes the output barrel when there
  is none; otherwise it waits on the refinery's tile, and no more feed is taken
  until an arm removes it. A barrel without feedstock becomes the output barrel
  when there is none. The refinery starts itself when it has feed, an output
  barrel with room and cable power, never twice. A full output barrel is
  offered; taking it stops the refinery and releases its power.
- **Engines:** a secured internal combustion engine with a connected fuel tank
  takes a barrel of a fuel it burns, tops up the tank and leaves the barrel on
  its tile to be taken. The tank itself is never offered.
- **Barrel station** (`/obj/structure/reagent_dispensers/largebarrel/factory_station`,
  12 steel, Factories): a secured 1,000-unit inert tank that drains barrels
  into itself or fills them from it (Switch Station Mode), one at a time, and
  hands each barrel back. Locks and hand use work as on any large barrel.
- **Reagent gate** (8 steel, Automation): a sorting gate whose filter is the
  main reagent of the container held when it is set, or empty containers.

Refinery changes: hand-loaded output barrels are now held inside the refinery
instead of in nullspace, so they are saved with it. The barrel list and the
refine loop are runtime-only; load rebuilds the list from the held barrel and
leaves the refinery stopped, because no refine loop survives a restart.

Lab distillery, centrifuge and chem master work on beakers and vials, so they
stay manual until the pipe phases.

Verification: `tests/factory_automation/chemistry_probe.dm` (see the README in
that folder). Not verified: a full disk save/load round trip and in-game play.

## Phase 1 as built

`code/modules/1713/factory_pipes.dm` adds pipe networks, stepped every two
seconds by the factory process:

- **Fluid pipe** (1 steel), **pipe valve** (2 steel), **fluid pump** (6 steel,
  3 PU), **holding tank** (10 steel, 1,000 units) and **water intake**
  (4 steel), all at Factories. Pipes join every adjacent pipe and machine
  (including one on the pipe's own tile); a closed valve joins nothing. Pipes
  reuse the existing atmospheric pipe sprites and redraw as straight runs,
  bends and junctions.
- Pipes hold no reagents. A network is rebuilt only when a pipe, valve, pump,
  tank or intake changes, and at least once a minute so machines placed next to
  pipes join it. Networks are runtime-only and rebuilt after load.
- Each step, a network with powered pumps moves 20 units per pump. Sinks
  (refinery feed, engine fuel tanks, filling barrel stations) take first, from
  sources (oil well barrels, refinery output barrels, water intakes, draining
  barrel stations) and holding tanks; then holding tanks take from sources.
  Tanks never trade with tanks. Each transfer moves one reagent and keeps its
  data. A network that moved nothing looks again every five steps.
- A holding tank is inert; Set Tank Filter limits it to one reagent.
- A water intake beside open water supplies what a person filling a container
  there gets: cholera from sickly water, salt from salt water, irradiated
  water from irradiated turfs.
- The oil well still needs its barrel, which acts as the wellhead tank; pipes
  draw petroleum from it. A piped refinery still needs an output barrel and
  starts itself when fed.

Verification: `tests/factory_automation/pipes_probe.dm`. Not verified: a full
disk save/load round trip, in-game play and how the pipe sprites look in game.

## Phase 2 as built

`code/modules/1713/factory_vessel.dm` adds the **reaction vessel** (14 steel,
200 units, 4 PU, Factories). It is inert, joins a pipe network like any
machine, and runs one recipe chosen by hand from the reaction bench's list
(`controlled_reaction_paths()` in `code/modules/reagents/laboratory.dm`, which
both now share):

- **Filling:** as a sink it takes only the recipe's inputs, in ratio, up to
  as many whole batches as fit beside the catalysts, plus each catalyst's
  required amount.
- **Reacting:** once the batch is complete it needs cable power for three
  steps (six seconds), then reacts the whole batch at once and releases its
  power. A batch that cannot react, such as a fibre recipe before its year,
  consumes nothing and waits.
- **Emptying:** as a source it lets out the product and any leftovers;
  catalysts stay for the next batch. Holding tank filters sort product from
  leftovers, so an unfiltered tank serves as the waste output. When only
  catalysts remain it fills again.
- Choosing another recipe, or none, first flushes everything, catalysts
  included.

Heated recipes (polypropylene) and bench-only recipes (gelatin foam, rayon and
lyocell fibre) now ask `controlled_reaction_site()`, which accepts a secured
bench beaker (heated by its burner when needed) or a powered vessel. Item
products such as cloth and plastic sheets stay on the bench (see phase 3).

Verification: `tests/factory_automation/vessel_probe.dm`. Not verified: a full
disk save/load round trip and in-game play.

## Phase 3 as built

`code/modules/1713/factory_packaging.dm` and two vessel subtypes:

- **Bottler** (8 steel, Automation): a pipe sink with a cradle for one
  container. Belts and arms bring it open containers that hold nothing but its
  reagent (Set Bottler Reagent, chosen from a held container); it fills each
  from the pipes and offers it back once full.
- **Automatic tablet press** (12 steel, 2 PU, Pharmacology, after 1843 as the
  hand press): a pipe sink that keeps an inert 40-unit buffer of calcium
  carbonate and aspirin in tablet ratio, and with power presses one aspirin
  tablet (one carbonate, four aspirin, as the hand press) a step onto its tile
  for arms, waiting once twelve items lie there. The hand-run press is
  unchanged.
- **Fast reaction vessel** (20 steel, 8 PU, Automation): 400 units, reacts on
  the first powered step. **Industrial reaction vessel** (30 steel, 15 PU,
  Digital Computing): 1,000 units, the same.

Not built: piped reagents as fabricator inputs, and the bench's item products
(cloth, plastic sheets, bottles) in the vessel. Fabricator recipes take items
only, and the bottler already moves piped liquids into containers that belts
carry; both stay open for later if play shows a need.

Verification: `tests/factory_automation/packaging_probe.dm`. Not verified: a
full disk save/load round trip and in-game play.

