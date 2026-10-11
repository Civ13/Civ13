# Polyethylene regression probe

Run `./tests/chemistry/run.ps1 -ByondBin 'C:\Program Files (x86)\BYOND\bin'`.
Use BYOND 516.1681 or newer, as required by the production checkout.
The runner compiles the production sources with normal world startup replaced,
then runs the real reagent holders and chemical reactions in temporary storage.
It does not start game schedulers, a client, or configured live-service adapters.

Checks cover elemental precursor recipes, polyethylene yield, missing catalysts,
catalyst retention, and rejection of propylene as polyethylene feedstock.
Logs remain in the printed temporary directory; generated build files are removed.
This is an isolated chemistry runtime check, not graphical gameplay acceptance.

The CI build job also runs `run.py --byond-bin <absolute BYOND bin directory>`
using the installed pinned Linux toolchain, followed by `--negative-control`.
The negative control restores the wrong propylene feedstock in a generated
recipe copy and requires the probe to detect it. Production files are untouched.
The portable runner also accepts the Windows BYOND bin directory when invoked
with a verified absolute Python interpreter path. Each runtime is bounded to
45 seconds and uses temporary storage. The Windows runner also closes to new
clients using its platform-specific launch flags.

For local client evidence, use the portable runner with `--visual --port 18329`
on Windows, after confirming the port is free. It starts a task-owned invisible
daemon with temporary storage and a 15 minute watchdog, prints its localhost
URL and writes `process.json` with its PID. Close that process when done.
Connect a local client only during an authorized capture turn. The fixture
replaces lobby Login and normal world startup. `Inspect chemistry` displays real
beaker contents; `Run chemistry` invokes production `process_reactions()` and
verifies positive/missing-catalyst/wrong-feedstock cases. These fixture verbs are
not the normal crafting menu. Ordinary CI also verifies those real beaker cases.

## Gasoline precursor registration

Use `run.py --probe fuel --byond-bin <absolute BYOND bin directory>` for four
existing precursor recipes and real-beaker gasoline mixing. Two complete
10 octane / 4 cyclopentane / 5 toluene / 1 butene batches must produce 40 gasoline.
Missing butene or only 0.5 butene prevents mixing and preserves the inputs.
`--probe fuel --negative-control` removes octane registration in a generated
copy and requires the original missing-product failure. CI runs both modes.
Visual mode supports `--probe fuel --visual` with the same localhost adapter.
Fuel recipe ratios, engine consumption, ethanol blends and balance are unchanged.

## Controlled laboratory processing

`run.py --probe processing --byond-bin <absolute BYOND bin directory>` runs
all 23 offered reactions through production beaker transfer and bench synthesis.
It checks exact products, consumed reactants, retained catalysts, the carbonate
to chloride chain, reagent phases, and rejected missing-input/overflow/unknown
recipes. It verifies inert-beaker restoration, preexisting inert flags, and
collector survival when the bench is destroyed. The production catalog parser,
research mapping, generated crafting recipe, stack consumption and actual bench
constructor run, including occupied-tile and insufficient-glass rejection.

This probe removes the normal map, world/global/controller startup and uses a
30x30x1 test world, temporary catalogs/names and a constructor-only human adapter.
The craft timer is set to zero; timed builds, menu clicks and character startup
are not verified. Runtime error diagnostics fail the check. Processing has no
visual mode. `--probe processing --negative-control` removes NMMO registration
in a generated copy and must detect the missing output before consuming inputs.

## Full Chemistry Recipes acceptance

`run.py --probe biochemistry --byond-bin <absolute BYOND bin directory>` adds:

- Actual construction of finite feedstock dispenser (20 glass), extraction kit
  (14 iron), burner (4 iron) and centrifuge (24 electronics) via their generated
  research-gated production recipes and output constructors.
- Fourteen feedstocks through production dispensing/transfer, capacity/depletion
  rejection, and hydrogen chloride-to-hydrochloric acid.
- Natural jungle seed-list registration, seed-to-plant construction, real ready
  crop harvest and meat/vomit/papaya extraction. Spoiled, unknown and nonempty-kit
  cases preserve sources.
- Cold/expired/empty/remote burner rejection, actual fuel filling/consumption and
  heated polypropylene with retained catalysts.
- Scaled 9:1 gasoline/purified-ethanol blending, missing-ethanol rejection and
  real gasoline-engine consumption. Ordinary gasoline consumption is unchanged;
  diesel-only engines reject the blend.
- All six gelatin treatment/finishing combinations, production transfers, exact
  centrifuge yields, all blood fractions, unknown/full-collector rejection and
  the actual 15-second callback with powered/lost-power/lost-collector cases.

`--probe biochemistry --negative-control` removes enginefuel registration in a
generated source copy and requires the missing-product failure. CI runs both.
All 32 offered recipes run through inherited processing checks. Success requires
every check to finish without a recorded failure; the fixture error handler
preserves runtime diagnostics without normal game error infrastructure.

External power is injected for the timed callback. Craft timers, character
construction and installed dispenser containers are explicit adapters; harvest
starts at a ready stage. This does not prove player menu clicks, crop growth
duration, power-network integration, syringe collection, ordinary-map progression,
production-server or graphical acceptance. Temporary storage and the 30x30x1
world remain isolated; only needed observation datums are initialized. There is
no visual mode. Player paths and game choices: docs/chemistry-recipes.md.

For gameplay replication, use an isolated game and a reagent container with
adequate capacity. Mix 2 units of ethylene with 10 titaniumchloride,
5 borontrifluoride, and 5 aluminumchloride. Expect 25 polyethylene and unchanged
catalyst amounts. Omit a catalyst to verify no polymerization; substitute
propylene for ethylene to verify that it does not produce polyethylene.
