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

Roles: edge, striker, handle, gear, bearing, spring (in a mechanism), limb
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
