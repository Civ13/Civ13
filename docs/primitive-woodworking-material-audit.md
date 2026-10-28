# Legacy sharp working materials

Flattening first checks actual sharpness, sharpened-flint state and actual
`get_material()` data. Actual wood rejects even if the item type also has a legacy
declaration. An exact reviewed legacy declaration is used only when that API
returns null. It establishes **non-wood working material for flattening only**;
it does not change global material data, assign instance alloy/hardness, make the
object a whittling knife or charge tool wear. Unknown subclasses do not inherit it.

| Exact legacy type(s) under `/obj/item/weapon/` | Existing source evidence |
|---|---|
| `surgery/scalpel/bronze`, `surgery/bone_saw/bronze` | Inherited sharp flags in `surgery_tools.dm`; bronze recipes in `material_recipes_global.txt` lines 1942/1944 |
| `surgery/scalpel`, `surgery/bone_saw` | Sharp definitions; global iron recipes at 2452/2454, Camp/Voyage steel recipes. Both variants establish non-wood; precise instance alloy stays unknown |
| `wirecutters` | Sharp definition in `weapons/tools.dm`; steel recipe at global line 1798 |
| `plough/iron` | Sharp iron subtype in `1713/tools.dm`; iron recipe at global line 2371 |
| `reagent_containers/syringe` | Sharp base syringe; iron recipe at global line 2455. Other injector types are not assumed to share this recipe |
| `attachment/bayonet` | Sharp bayonet; iron recipe at global line 2408. The flag subtype has sharp=false and is excluded |
| `gun/projectile/ancient/firelance` | Sharp spear/fire-lance definition; iron recipe at global line 2466 |
| `broken_bottle` | Glass-bottle shatter path creates this sharp object; its definition retains glass drop behavior |
| `macuahuitl` | Definition explicitly describes a wooden club with **obsidian blades**. The working blades qualify, while a wooden working surface does not |

The executable evidence table is
`tests/primitive_woodworking/legacy-working-materials.json`. Regressions exercise
every listed actual type, unknown subclasses, actual wooden overrides,
after-wait loss of sharpness, unchanged durability and unchanged whittling rules.

## Audit coverage and refusals

The private static audit read all 1,268 `code/*.dm` includes in DME order, traced
root-level type declarations, explicit `parent_type`, inherited sharp defaults
and the two item families that actually implement material data. It identified
142 statically sharp item types lacking that API, originating from 19 sharp
declaration roots. Material weapon parts and shards already use real material
data and require no fallback. Runtime flint sharpening and bayonet mode changes
were also read; runtime sharpness is checked again after waiting.

The remaining cases are deliberately refused without stronger material evidence:
the sharpened wooden branch; ordinary saw and boltcutters with unspecified
working material; other syringe/injector subclasses without an exact material
recipe/declaration; and projectile/spell-effect types without a working-material
API/declaration. Names, conductivity and a sharp flag alone do not prove non-wood.
The audit lists all 142 types and their recipe references in the private review
packet. Its root-level parser is source evidence, not native type introspection
or a claim to resolve every runtime material mutation.

No source outside woodworking is assigned a new material. Future declarations
must add source evidence and actual-type regressions to the same table; existing
runtime material data always takes precedence.
