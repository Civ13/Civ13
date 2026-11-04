# Component armor crafting

The armor assembly workbench is a staged textile route. Craft the bench from
10 finished planks using the material menu after unlocking Weaving.
The bench reuses the existing workbench sprite. Every existing material catalog
gains the same bench recipe, preserving acquisition across map/faction menus
when replacing the shared anvil's standard vest recipe.

Select a recipe by clicking an empty bench. Hold each complete input stack or
component and use it on the bench. Click Assemble, wait ten seconds, then use
Retrieve / cancel to collect the result and any excess stock. Inputs are real
items stored inside the bench. Each recipe is one batch, with no failure roll,
bulk discount, new skill threshold or added armor bonus.

| Recipe | Inputs | Output | Unlock |
| --- | --- | --- | --- |
| Armor carrier | 4 cloth + 2 leather | 1 carrier | Weaving, eras 0-8 |
| Aramid panels | 14 Kevlar sheets | 1 set of panels | Modern Armor, eras 7-8 |
| Standard aramid vest | 1 carrier + 1 set of panels | Existing black Kevlar vest | Modern Armor, eras 7-8 |

Modern Armor belongs to the specialist Tailoring tree: reaching era 7 alone
does not grant it. Research and era are checked at insertion, start and
completion. A pre-existing carrier can be made earlier, but cannot unlock panels
or a vest. The station's construction uses the existing Weaving mapping.

Aramid is the family represented by the existing Kevlar materials. This change
reuses their existing game chemistry -> raw Kevlar -> industrial acidic bath ->
prepared Kevlar -> loom -> Kevlar sheets path, including its existing yields and
processing behavior. It does not introduce a duplicate acid/nitrogen/hydrogen
reaction. The old fuel-and-acid reaction is an abstract game recipe, not a model
of real aramid chemistry. No practical manufacturing procedure is represented.

The standard vest's 14-sheet anvil recipe is replaced by this route. Total cost
remains 14 Kevlar sheets and adds 4 cloth plus 2 leather; the three assembly
stages take 30 seconds total, excluding upstream weaving and chemistry.
The output is exactly the existing black Kevlar vest, with unchanged coverage,
armor, weight and slowdown. Existing vests and saves remain compatible. Other
anvil helmets, PASGT equipment and map/material-menu civilian/6B3 armor recipes
are intentionally unchanged; those are distinct outputs, not alternate routes
to the standard vest. They need separate balance decisions before migration.

Retrieve cancels pending work without consuming ingredients, and destruction
returns stored items. The bench retains its busy lock until the old wait returns.
Completion rechecks the exact stored objects, quantities, actual stack material,
station location, actor access, recipe, research and persistence admission identity.
Changed stock, missing inputs, movement, research loss and save/load admission
invalidate completion before any payment. Saved contents survive; runtime locks
and actor references do not. Excess stock remains stored until retrieved.

The armor-specific recipe table extends the existing component bench pattern;
it does not alter the tool bench or generic material-stack crafting. Additional
recipes can pair a textile carrier with metal/scale/lamellar components using
the same staged path once their costs, research, output and art are reviewed.
Earlier-era armor, helmets, modular insert bonuses, repair, salvage and dynamic
armor stats are outside this slice.

The component fixture executes production bench, material, wait, deletion,
inventory-transfer and serializer paths with isolated player startup/HUD/slot
adapters. It covers costs, excess, gates, cancellation, concurrent calls, stock
tampering, movement, destruction and nested native save/load. It does not prove
connected-client menus, full-map progression or the safety of unchanged upstream
chemistry/bath/loom processing. Windows uses the existing owned-Job/no-socket
supervisor; Linux uses the existing manual component-tools workflow.
