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

- Padded: linothorax, padded jack (under-layer), aztec harness, padded head-caps, arabic turban helmets,
  emirate turban.
- Leather: leather armor, steppe leather armor (laced), leather helmet,
  skullcap, hatchigane, khepresh.
- Lamellar and scale: leather samurai armor and helmets (laced), metal samurai
  armor and helmets, bronze egyptian and chinese lamellar, scaled and segmented
  armor, alligator scale (hide), chitin, varangian lamellar, imperial chinese
  armor, kote and tsuranuki.
- Mail: early and medieval chainmail, chainmail on the armor slot, hauberk, emirate armor, coif, mamluk coif.
- Plate: plated armor and its colors, samurai lord armor and helmets (steel),
  bronze, iron and imperial chestplates, medieval, roman, gaelic and classical
  bronze helmets, sallets, morion, cabasset, gauntlets, plated boots, proof
  cuirass and proof do (steel).

## Layering

A padded jack (5 cloth, crafted like linothorax) goes on the uniform's armor
slot under any suit armor. As an under-layer (`armor_underlayer`) it keeps the
padded blunt value (39) and half the arrow value (15) and gives nothing
against cuts or thrusts, so it covers mail's weakness to blows without
stacking blade protection. Layers add up as worn clothing always has.

Chainmail worn on the armor slot protects as iron mail. A thrust finds the
gaps in mail and lamellar on the struck part unless plate also covers it
(`docs/melee-hit-kinds.md`).

Fantasy, sci-fi, modern and other armor has no family and keeps its own
values; cut, pierce and blunt fall back to its melee value.

## Armor against guns

The proof cuirass and the japanese proof do (anvil, steel, Imperial age on)
are steel plate on the torso with gun 30 and slowdown 1.0, the first armor
that turns many musket balls. The resin body shield (armor assembly workbench,
8 cloth and 4 resin, Trench Warfare, WW1 on) is a light vest with gun 25
against shrapnel and pistol rounds. Their sprites are drawn by Fable.

## Telling players

Examining a family piece adds one line saying what it is good and bad against
and what it is made of (`armor_family_strengths`); an under-layer says it
softens blows and arrows. A thrust that gets through mail or lamellar tells
both sides it found a gap, and a blow stopped by armor tells the wearer it
bruised them.

## Era windows

Armor never goes out of date. Every armor and helmet anvil row and every
family material recipe is craftable from its first age to the end
(`RECIPE_OPEN_ENDED_AGE`), and the anvil keeps offering its armor categories
for iron, steel and bronze in every later age. Plated armor can also be forged
from steel.

Tested by `tests/armor_families`.
