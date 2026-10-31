# Controlled laboratory recipes

The laboratory reaction bench is crafted from 10 glass in the chemistry category,
under the same apothecary research gate as the laboratory distiller. It appears
in the global and Carib catalogs through the Modern Age. Its normal craft time
is 140 ticks before the game's skill modifiers.

Insert a glass container, then use other glass containers on the bench to pour
their selected transfer amounts into it. The installed container is held inert,
so shared elemental ingredients cannot react before the desired mixture is
complete. Click the bench to select a recipe. Missing reactants/catalysts,
unregistered outputs and insufficient output capacity reject the operation
without consuming inputs. Remove reaction beaker ejects the container and
restores its original inert state. Destruction also releases the container.

The bench offers the existing ethanoic acid, calcium salts, wood-processing
reagents, isobutylene, polymer precursors/catalysts, polyethylene and gasoline
chain. These deliberately simplified game conversions and yields are not
laboratory synthesis instructions. Many existing elemental recipes share
ingredients; ordinary automatic mixing cannot reliably select between them.
The bench lets the player choose explicitly without changing those old recipes.

This phase restores product registrations for ethanoic acid, calcium chloride,
gluconic acid, calcium gluconate, sodium sulfide/hydroxide, sulfurous acid,
hydrogen sulfites, NMMO and isobutylene. Calcium carbonate is 1 calcium + 1 carbon
+ 3 oxygen -> 5 carbonate. One carbonate + 2 chlorine -> 3 calcium chloride,
using the corrected `calcium_carbonate` ID. Sodium hydroxide is corrected to
1 sodium + 1 hydrogen + 1 oxygen -> 3 units.

Liquid titanium tetrachloride retains the existing `titaniumchloride` ID and
1 titanium + 4 chlorine recipe. Solid titanium trichloride has a separate
`titaniumtrichloride` ID and 1 titanium + 3 chlorine -> 4 units. Existing catalyst
references still use the liquid reagent. Existing isobutylene uses 4 carbon +
8 hydrogen; the issue's C4H10O label describes a different compound.

Verification commands and adapters are documented in tests/chemistry/README.md.
The processing fixture executes production transfers, selected reactions and
construction, but it does not click menus or test timed character interactions.
The subsequent gelatin, heat/polypropylene, fuel and player acquisition paths
are documented in [Chemistry Recipes](chemistry-recipes.md).

## Grinder transaction safety

The powered grinder retains the exact installed stack, type, material, count,
tile and cable connection through its existing 10-second and 5-second waits.
Both stages reject changed input or a cancelled/replaced operation. A failed
power check invalidates that operation, including after power returns and a new
cycle starts. Destruction cancels the cycle and releases its installed input
onto the machine's turf before ordinary contents cleanup. Save/load admission
also invalidates an in-flight operation; the running flag and callback owner
are runtime state, while installed stock remains durable.

Each complete five-log batch produces one distinct batch of wood chips. This
retains the conservative counted ratio as a gameplay unit, not a physical yield
measurement: one batch contains five log units' worth of chips. Partial batches
remain installed. Fewer than five logs, fractional/oversized stacks, burning wood,
wood claimed by woodworking and other materials cannot start a conversion.
Output is constructed with its final integer count and automatic merging
disabled. Chips stack up to ten batches, the feedstock equivalent of one 50-log
stack, and cannot substitute for ordinary wood in crafting or convert back to logs.

Hold chips and use them on an adjacent oven, campfire or wood stove. Each batch
is paid once and adds five of the oven's existing fuel units and five paid-wood
residue units, exactly what its five input logs would supply. Loading creates no
ash; only burning paid fuel can produce ash through the existing ledger. No
other fuel family, wood recipe, pulp conversion or chemical product is added.

### Acquiring a grinder

The global crafting catalog offers a wood grinder for a nominal 20 electronics,
with a base duration of 120 deciseconds. Strength and crafting coefficients scale
that duration through the existing builder. Construction requires a 20-unit
stack even when Production's existing discount makes the actual debit 18.
There is no added grinder crafting-skill gate. Crafting the circuits themselves
requires a crafting coefficient of at least 2.2 and copper with iron in the other
hand: nominally one copper and one iron per circuit, subject to existing bulk
discounts. Trade or existing stock can supply electronics instead.

The exact constructed variant unlocks under Electricity (era tier 5, minimum
bench tier 4, Steam Power prerequisite and a cable prototype). Existing faction
completion and baseline-era grants apply; this adds no calendar-year gate. The
recipe's maximum era is 8. It is global-only: camp, Carib and species catalogs do
not gain it. Wizard Boy's mapped base grinder and camp catalog are unchanged.
Catalog availability does not prove a map's resources or full progression path.

The crafted machine starts empty, off and unanchored. Use the existing wrench
(five iron, Basic Toolmaking), then connect a paid cable run with 30 available
capacity after other loads. A white coil costs one copper for ten cable pieces;
its Paved Infrastructure gate permits Electricity's cable prototype. A steam
engine with two lit adjacent heatsources is an existing source-backed option
for 30 capacity, not native or map-level acceptance. One jar cell, voltaic pile
or lead-acid battery alone supplies only 1, 5 or 10 respectively.

Crafted grinders cannot be dismantled and return no structural materials. To
relocate one, remove cables with wirecutters, unfasten it with a wrench and move
it. This leaves mapped grinders' existing behavior intact and avoids generic
wood salvage or a nominal-electronics refund exceeding the actual paid debit.
No pulp, additional operation or transaction change is introduced; remaining
requirements of #2301/#2303 stay separate.

`tests/grinder/test_transaction.py` checks the transaction offline using source
projections, deterministic callbacks and external adapters. It does not establish
native compilation, real power-network integration, savefile round trips or
gameplay. Power is sampled at start and both wait completions, and by other
callers of `check_power()`; an outage that disappears between all observations
is not recorded by the existing cable system. See its [verification notes](../tests/grinder/README.md).
