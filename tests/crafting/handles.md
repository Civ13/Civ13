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

The existing title predicate is unchanged. At base cc03b199, it matches 74 active
rows across the material recipe catalogs and these ten distinct global titles:

| Title | Global catalog line | Consumed material |
| --- | ---: | --- |
| bone hatchet | 1262 | bone |
| battle axe | 1263 | bone |
| bone pickaxe | 1265 | bone |
| bone shovel | 1266 | bone |
| stone pickaxe | 1302 | stone |
| stone hatchet | 1303 | stone |
| bamboo spear | 2323 | bamboo |
| trench shovel | 2374 | iron |
| sandstone hatchet | 2543 | sandstone |
| pickaxe | 2545 | sandstone |

The predicate also contains legacy sledgehammer names, with no active catalog rows
at this base. Wood spears and molds keep their existing exclusions. This change
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

Checks cover all ten global titles, both hands/back/shoulder/belt cleanup, full
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
