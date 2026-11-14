# Material properties and part roles

One rule for "the same thing in a different material": a thing is a design
plus the materials in its slots, and its numbers come from those materials.
This page covers the first layer, the properties and the roles. Slots on
tools and machines, and the standard parts (gear sets, shafts, bearings),
build on it in later changes.

## Properties

Every `/material` has the same properties, set in
`code/modules/materials/material_properties.dm`. Steel is 100 on every scale
except `heat_limit`, so a value reads as "percent of steel".

| Property | Answers |
| --- | --- |
| `density` | How heavy is a part of this size |
| `firmness` | Does it keep an edge, does it dent |
| `toughness` | Does it snap under shock |
| `wear` | How long does it last as a rubbing or rolling part |
| `heat_limit` | Deg C before it chars, softens or melts |
| `corrosion` | How fast water ruins it, 0 = never |
| `conductivity` | Copper = 100 |
| `spring` | Does it return after bending |
| `flammable`, `magnetic`, `sparks`, `toxic` | Flags |
| `shaping` | `SHAPE_*` ways it can be worked |

The older `hardness`, `weight` and `integrity` are weapon and structure
balance numbers (hardwood has hardness 200) and are not physical properties.
They keep their meaning and values; `tests/material_roles/legacy_values.json`
freezes them. The one deliberate change is gold's hardness, 70 to 30, which
had a gold blade out-cutting a steel one.

Unlisted materials inherit the base values, which describe hides, cloth and
fibre. A new material sets its own block in `material_properties.dm`.

## Roles

A `/datum/part_role` (`code/modules/materials/part_roles.dm`) names the
standard material for a job and the properties that matter. Ask for a rating
by role id and material name:

```dm
var/list/rating = part_rating(ROLE_GEAR, "bronze") // list(performance, lifetime, mass) or null
part_performance(ROLE_EDGE, "flint")               // 0 when refused
part_refusal(ROLE_SPRING, "lead")                  // "lead has no spring"
```

Performance is bounded to 25%-125% of the standard part and lifetime to
5%-200%; mass is unbounded. A role refuses a material that cannot do the job
at all: too fragile for shocks, too soft for a gear, bearing or wheel, below
the role's heat floor, flammable for a vessel, or zero in a property the role's performance depends on.

Roles: edge, work_head (pick, axe and shovel heads), striker, handle, gear, shaft, bearing, spring (in a mechanism),
belt (a drive belt, rope drive or chain; leather is its standard), limb (bow or crossbow), pipe, vessel, conductor, wheel. `ROLE_FRAME` and `ROLE_PLATE` are reserved ids rated by the vehicle
materials work.

Ratings are worked out once per role and material and cached. Materials and
roles are singletons, so nothing here adds memory per item.

## Balance rule

`python3 -m unittest discover -s tests/material_roles -v` mirrors the rating
formula. `BEATS_STANDARD` lists the only materials allowed to outperform a
role's standard; a new material that turns out better fails the suite until
that is a decision. `FROZEN_RATINGS` pins a sample so a changed formula or
value is deliberate.

Material items show a "Material:" line on examine built from
`/material/proc/property_summary()`.

## Tool speeds

`code/modules/materials/tool_speeds.dm` holds one table per tool family
(pickaxe, shovel, hatchet) with the speed each hand-made material always had.
`tool_material_speed(family, material)` returns that exact number for a listed
material. Any other material (a cast copper or bronze head) is placed between
its listed neighbours by its `work_head` performance and never leaves the
listed range. `set_material()` applies it to the plain family tool; variants
with their own hand-set speed (jackhammer, spades, battle axes, chainsaw) keep
it. Assembled head-and-handle tools use the same head speed times the handle
factor (docs/component-tools.md).

Plain tools that are not material items name their material in
`tool_material`; `tool_material_name(item)` reads either kind.
`python3 -m unittest discover -s tests/tool_material_speeds -v` checks the
table against the named variants and pins the in-between values.

## Plain tools

A hammer, chisel, wrench, screwdriver, saw, shears, wirecutters or crowbar is
not a material item. It sets `tool_noun` and `tool_role`
(`code/modules/materials/tool_materials.dm`), and a recipe row whose last field
names a material builds the same type in that material:
`set_tool_material()` renames it ("bronze wrench"), tints it and records the
material in `tool_material`. A tool in its usual material stores nothing.

`tool_speed(item)` is the tool's role performance against its usual material,
1 for every tool that existed before and 0.4 to 1.5 otherwise;
`tool_work_time(item, delay)` applies it. Sawing logs into planks and wrench
fastening use it today; other work sites adopt it as they are touched.

The rows come from `config/recipe_variants.json`: per product, the existing
catalog row to copy and the other materials. `python3 scripts/recipe_variants.py
--write` rewrites the marked block at the end of
`config/crafting/material_recipes_global.txt` as ordinary `RECIPE:` rows, so
every reader of the catalog keeps working. `tests/tool_materials` fails when
the block is stale and pins each pair's speed.

## Machine parts

`code/modules/materials/machine_parts.dm` defines the standard parts a machine
is built from. Each is one item type that takes a material name when created,
like a knife:

| Type | Role | By hand (tool) | Anvil, Parts kind | Parts mould |
| --- | --- | --- | --- | --- |
| `/obj/item/machine_part/gear` | `ROLE_GEAR` | wood, bone (chisel) | bronze, iron, steel | copper, bronze, brass, iron, steel |
| `/obj/item/machine_part/shaft` | `ROLE_SHAFT` | wood (hatchet) | bronze, iron, steel | copper, bronze, brass, iron, steel |
| `/obj/item/machine_part/bearing` | `ROLE_BEARING` | wood (chisel, 1 animal fat) | bronze, iron, steel | copper, bronze, brass, iron, steel |
| `/obj/item/machine_part/spring` | `ROLE_SPRING` | - | bronze, iron, steel | - |
| `/obj/item/machine_part/belt` | `ROLE_BELT` | rope, leather, cloth (knife) | bronze, iron, steel (a chain) | - |

A part stores `part_role`, `part_material` (a name), `precise` (cut on a
lathe; hand, forged and cast parts are rough) and `wear` (0 to
`MACHINE_PART_WORN_OUT`). It holds no list and no material datum:
`P.rating()` asks `part_rating()` for performance, lifetime and mass. Examine
shows the percentages. These type paths are stable; machines and other work
may name them.

Hand rows are ordinary catalog rows whose last field is the material; their
tools and the bearing's animal fat are in `config/craft_needs.json` (an input
that is not a stack pays whole items). The anvil rows are in `anvil_recipes`
under the kind "parts", offered for iron, steel and bronze sheets in every
era. `/obj/item/weapon/clay/mold/parts` is fired like any mould, filled from a
blacksmith pot and worked on an anvil, where the shape is picked.
`anvil_recipe_offered()` asks `machine_part_refusal()` so no menu offers a part
in a metal that cannot do its job (no lead or tin gears) or a shape that
cannot be cast (springs, chains). Brass joined `anvil_mold_costs`, so brass
pours into every mould at the bronze cost.

## Lathes

`code/modules/materials/lathes.dm` adds two `/obj/structure/workshop_machine/lathe`
subtypes. Use sheet stock on a fastened lathe to turn a precise gear set,
shaft or bearing (`lathe_parts`: 4, 2 and 2 units), or use a rough part on it
to cut it true. Springs and belts are never turned.

| Lathe | Research | Built from | Cuts | Needs |
| --- | --- | --- | --- | --- |
| `lathe/pole` | Workshops | 8 wood, 2 rope | wood, bone, brass | a chisel held, worn or at your feet |
| `lathe/engine` | Machined Tools | 12 iron, a gear set, a shaft and 2 bearings of any material, a wrench | copper, bronze, brass, iron, steel | nothing; twice as fast |

Both are built from rough parts, so the first lathe never needs a lathe.
`precise` matters in machines that need precision (see Machine slots).

## Machine slots

`code/modules/materials/machine_slots.dm` gives a machine wearing slots for the
standard parts. `machine_slot_tables` maps a machine type to its slots, each
with the part type it takes and the material the machine is built with today;
the nearest listed ancestor applies.

| Machine | Slots | Built with |
| --- | --- | --- |
| `/obj/structure/mill` | shaft, bearing | wood |
| `/obj/structure/mill/large` | gears, shaft, bearing | wood |
| `/obj/structure/sawmill/large` | gears, shaft, bearing | wood |
| `/obj/structure/sawmill/powered` | gears, shaft, bearing | iron; needs precision |
| `/obj/structure/loom` | shaft, bearing | wood |
| `/obj/structure/printingpress` | shaft (the screw) | wood |
| `/obj/structure/civ_generator/waterwheel` | shaft, bearing | wood |
| `/obj/structure/civ_generator/wind/charger` | gears, shaft, bearing | iron; needs precision |
| `/obj/structure/civ_generator/wind/turbine` | gears, shaft, bearing | steel; needs precision |

A machine built the usual way stores nothing and runs at 100%. Two values on
`/obj/structure` hold everything else, so no machine carries a list:
`part_key` is text such as `gears=bronze;shaft=steel+` (slot=material, `+`
when precise; BYOND keeps one copy of each distinct string) and `part_wear`
packs six bits of wear a slot. That is why a machine has at most
`MACHINE_MAX_SLOTS` (4) wearing slots; `tests/machine_parts` enforces it.

```dm
machine_performance(M)        // weakest slot against the built-in part, 0.25 to 1.25; 0 when one is worn out
machine_work_time(M, time)    // time / performance
machine_work_refusal(M, user) // TRUE: a part is worn out, or a failing part jammed (15%)
machine_wear(M, jobs)         // charge wear; a part lasts by its material's lifetime rating
machine_install_part(M, P, H) // fit a part item; a part someone fitted earlier comes back out
machine_examine_parts(M, user)
machine_drop_fitted_parts(M)  // on dismantling: hand back the fitted parts with their wear
```

A standard part lasts `MACHINE_PART_BASE_LIFE` (400) jobs in its own design.
Wear 21 and up is worn (a quarter slower), 42 and up is failing (may jam), 63
is worn out (the machine stops until the part is replaced). In a machine
listed in `machine_precision_types`, a rough part someone fitted is capped at
60%; the built-in part and lathe-cut parts are not. The part a machine was
built with is scrap when replaced, so a one-step build never mints parts.

To give another machine slots: add its row, call `machine_work_refusal()`
before work, scale its time or progress with `machine_work_time()` or
`machine_performance()`, call `machine_wear()` when a job finishes, and pass
part items to `machine_install_part()`. The mills, saw mills and loom do this
by wrapping their own procs in `machine_slots.dm`.

The printing press charges its screw one job a finished print, and its print
times go through `machine_work_time()`. A wind or water generator multiplies
`rated_output()` by `machine_performance()`, so a worn-out part means no
output, and never jams. It runs every second, so it is charged wear at a 1%
chance a second, a tenth of a job each time: a standard set lasts about 110
hours of output (`MACHINE_RUNNING_JOB_SECONDS`).

Taking a machine apart with a hammer (`hammer_action()`, the plain structure
dismantle and the press's own) calls `machine_drop_fitted_parts()`: parts
someone fitted come back with their wear, the built-in ones and worn-out ones
do not. The standing clock and hand-held machines such as crossbows have no
slots; slots live on `/obj/structure` only.

## Sparks

A tool whose material has `sparks` set (iron, steel, flint) can set off a
barrel holding powder or fuel when it is struck against it on harm intent:
`/atom/proc/struck_by_tool()` is asked before every `attackby()` and the
barrel's override in `tool_materials.dm` rolls 4% a blow, logged to admins.
Bronze, copper, wood and bone tools never spark. The barrel's examine text
warns while its contents are volatile. Ordinary use of a barrel (filling,
pouring, carrying) never rolls.
