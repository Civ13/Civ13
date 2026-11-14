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

Roles: edge, work_head (pick, axe and shovel heads), striker, handle, gear, bearing, spring (in a mechanism), limb
(bow or crossbow), pipe, vessel, conductor, wheel. `ROLE_FRAME` and `ROLE_PLATE` are reserved ids rated by the vehicle
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
