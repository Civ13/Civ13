# Consumed wood handles

Stack recipes that already consumed a wood handle now accept a removable handle
in the actor's hands or equipment, including the back, shoulder and belt fields.
The selected item must be directly owned by that actor and occupy a real equipment
slot. Left hand and right hand retain priority, followed by the existing equipment
priority list. Other actors, ground handles, loose non-slot contents and nested
containers are excluded. This applies even to open storage: the existing recursive
get_contents/return_inv helpers do not enforce container accessibility.

The same selected handle survives the construction wait. Cancellation preserves
its identity, name and quality. Moving it out of accessible owned equipment or
deleting it aborts without substituting a spare; moving between eligible owned
slots remains valid. Both the source stack and selected handle are checked again before the
material debit. Only a successful stack.use consumes the handle, through actual
slot removal and qdel. No clone-based handReturnMap refund is used for handles.
Normal menu crafting still requires a held material stack. Direct production
callers retain access to nearby ground material stacks; transfer or nesting of the
source stack during the wait cancels that attempt. Full hands do not prevent use
of an equipped handle; the existing recipe output remains on the floor.

The predicate lives in `code/game/objects/items/stacks/craft_needs.dm`:
`crafting_handle_title_words` (substrings: hatchet, shovel, pickaxe, spear,
battle axe and the sledgehammer names), `crafting_handle_titles` (exact titles)
and `crafting_handle_title_exclusions` (wood spear, mold, steam shovel - a machine, not a hafted tool). The Crafting window
lists the handle through `/datum/craft_guard/handle`, and the Crafting Atlas
reads the same three lists, so a new hafted tool is added in one place.

The exact titles are the hafted tools that used to cost only their head
material: stone rammer, stone adze, stone-headed club, copper, bronze and steel
hammer, clawhammer, copper, bronze, iron and steel hoe, pitchfork and fire hook.
Wooden versions (hammer, hoe, spade, digging stick) stay handle-free, and the
metal sickles already pay their wood through `config/craft_needs.json`.

The handle's material carries into the finished tool through
`apply_tool_handle()` (material_weapons.dm), the same proc a head fitted by hand
uses: durability scales by the handle's integrity against wood (0.5-1.5x), and
pickaxe, shovel and hoe work speed by its weight against wood (0.75-1.25x). A sawn
plank handle lasts 35% longer and works 35% faster; a reinforced (iron) handle
lasts 50% longer at the usual speed. Tools without durability or a work speed
(rammer, hammers, fire hook, club) only use the handle up.

The sledgehammer names have no active catalog rows. Wood spears and molds keep their existing exclusions. This change
does not alter forging/held-tool requirements, other ingredient families, or the
explicit held-item attackby/insertion interactions in parts.assemble_work_tool and
component_workbench. Those interactions receive the item the player is actively
using, rather than searching inventory for an implicit recipe ingredient.

The existing compiled recipe runner includes handles.dm. It executes production
produce_recipe, do_after, use, equipment lookup/removal and real catalog material,
handle and output constructors. Character startup, skill coefficients/learning
and HUD painting are adapters; equipment fields are arranged directly, so this is
not connected-client equip/menu acceptance. Catalog time is shortened to four
ticks for waiting cases; costs, material/output types and the floor gate remain.

Checks cover every global title in both lists, both hands/back/shoulder/belt cleanup, full
hands, hand preference with a spare, insufficient materials, removal restrictions,
foreign/ground/loose/nested handles, cancellation with retained quality, material
debit failure, moved/deleted inputs, and concurrent attempts using one handle.
The hands-only control mutates only inventory lookup and must fail the first
equipped-back assertion. It represents the old lookup restriction, not byte-for-
byte historical cancellation/refund behavior.

With an allocated BYOND 516.1681 runtime:

```
python3 scripts/check-recipes.py --report recipe-checks.txt --evidence-dir <fresh-positive-dir>
python3 scripts/check-recipes.py --handle-hands-negative-control --evidence-dir <fresh-control-dir>
```

CI runs these in the existing compiled-recipe step and retains compiler/runtime
logs, handle case results and exact-head source hashes. The probe closes its native
port in world.New; this does not provide OS network isolation or prevent a
pre-world.New listener. No running game is updated by these tests. The production
change requires a newly compiled game and restart, with no save migration or round
reset required.
