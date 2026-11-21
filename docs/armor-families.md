# Armor families

Armor protects by how it is built (its family) and what it is made of (its
tier), never by which culture it looks like. Every look in a family and tier
protects the same. Code: `code/game/objects/armor_families.dm`; hit kinds are
in `docs/melee-hit-kinds.md`.

## Values

A family piece's protection against cut, pierce, blunt and arrow hits is
tier x the family multiplier, rounded and capped at 95. Its `melee` value is
the mean of the three melee kinds. Gun, bomb and other keys stay in the
piece's own armor list.

| Family | Cut | Pierce | Blunt | Arrow | Suit weight |
| --- | --- | --- | --- | --- | --- |
| Padded | x1.0 | x0.7 | x1.3 | x1.0 | 0.2 |
| Leather | x1.2 | x0.7 | x0.7 | x0.9 | 0.2 |
| Lamellar and scale | x1.2 | x0.8 | x0.9 | x1.3 | 0.5 |
| Mail | x1.4 | x0.8 | x0.5 | x0.9 | 0.6 |
| Plate | x1.3 | x1.3 | x1.0 | x1.4 | 1.5 (torso-only 0.75) |

Tiers: hide or cloth 30, laced leather 35, chitin 40, bronze 45, iron 55,
steel 65. Suit weights live in each type's apparel file; helmets, gauntlets
and boots keep their own weight.

Forged pieces take their tier from the metal at the anvil
(`grade_forged_armor` in `steel_grades.dm`): plated armor forged from iron is
iron tier, from steel steel tier. A graded stock lifts melee kinds by its blunt
grade and arrows by its pierce grade, never past 90 and never lowering a value.

## Families

- Padded: linothorax, aztec harness, padded head-caps, arabic turban helmets,
  emirate turban.
- Leather: leather armor, steppe leather armor (laced), leather helmet,
  skullcap, hatchigane, khepresh.
- Lamellar and scale: leather samurai armor and helmets (laced), metal samurai
  armor and helmets, bronze egyptian and chinese lamellar, scaled and segmented
  armor, alligator scale (hide), chitin, varangian lamellar, imperial chinese
  armor, kote and tsuranuki.
- Mail: early and medieval chainmail, hauberk, emirate armor, coif, mamluk coif.
- Plate: plated armor and its colors, samurai lord armor and helmets (steel),
  bronze, iron and imperial chestplates, medieval, roman, gaelic and classical
  bronze helmets, sallets, morion, cabasset, gauntlets, plated boots.

Fantasy, sci-fi, modern and other armor has no family and keeps its own
values; cut, pierce and blunt fall back to its melee value.

## Era windows

Armor never goes out of date. Every armor and helmet anvil row and every
family material recipe is craftable from its first age to the end
(`RECIPE_OPEN_ENDED_AGE`), and the anvil keeps offering its armor categories
for iron, steel and bronze in every later age. Plated armor can also be forged
from steel.

Tested by `tests/armor_families`.
