# Chemistry Recipes player paths

These are simplified Civ13 game conversions and yields, not laboratory
instructions, biological models or real engine-fuel recommendations.

## Equipment and acquisition

The reaction bench costs 10 glass under Apothecary. Insert a glass container,
then pour individual feedstocks from other glass containers using their selected
transfer amount. Its collector stays inert so shared elemental ingredients do
not react before you choose one of its 33 recipes. Missing inputs/catalysts,
unregistered outputs and output overflow preserve inputs. Ejection or destruction
restores the container's original inert state and releases it.

The laboratory feedstock dispenser costs 20 glass under Pharmacology and starts
with finite 100-unit stocks of existing full-dispenser elements plus carbon,
sulfur, boron, titanium, water and purified ethanol. Fill beakers via the existing
dispenser UI and refill stocks with reagent containers. Crafting a stocked device
is the game's paid starter-supply abstraction, not ore simulation. Existing coal,
sulfur and other ore extraction routes remain available; the ordinary empty
chemical dispenser retains its behavior.

The extraction kit costs 14 iron under Apothecary. An empty kit extracts 4 collagen
from a raw unspoiled meat slab, 4 digestive protease from a vomit decal, or 4 fruit
protease from one unspoiled papaya. Success consumes the source; nonempty kits,
unsupported and spoiled sources consume nothing. Pour extracts into the bench
before reusing the kit. These yields are game choices.

Papaya seeds enter normal wild seed gathering in jungle/savanna. Plant and tend
them through normal farming, then harvest with a knife, hatchet, bayonet or scythe
for fruit and replacement seeds. Papaya reuses the existing orange fruit/tree
sprites pending dedicated art; its name/description identify it. Only papaya is
introduced, rather than inventing enzymes for every fruit suggested in the issue.

The burner costs 4 iron under Apothecary. Fill it from a beaker of purified ethanol
(`pethanol`), then use it on the bench. One unit heats the secured beaker for one
game minute. Burner and bench must be adjacent on the same level. Ejection or
replacement clears heat, and expired heat cannot polymerize polypropylene.
This is a bounded game heat state, not a general temperature simulation.

The existing centrifuge costs 24 electronics under Pharmacology. Anchor it with
a wrench, connect the existing cable power system, and meet its medical skill
requirement. Pour input into it and install an empty vial as collector. A cycle
takes 15 seconds and requires power at both start and completion.

Equipment appears in global/Carib catalogs through the Modern Age. Carib gains
the existing 24-electronics centrifuge recipe with its Pharmacology gate. Map catalogs and
progression still determine which recipes a player is offered.

## Recipes and balance choices

The existing powered grinder turns five whole raw logs into one batch of wood
chips after its existing cycle. Unpaid remainders stay installed. One chip batch
contains five log units' worth of feedstock; this conservative 5:1 count is an
abstract gameplay unit, not a measured physical yield. Ten batches fill a stack.
Chips reuse the existing small-wood stock sprite and have their own name/type;
they cannot replace logs, planks or bark in crafting or be converted back to logs.

An adjacent oven, campfire or wood stove accepts held chip batches. One batch
adds five existing oven fuel units and five paid wood-residue units, equal to
the five logs consumed. Ash appears only when paid fuel burns, not when loaded.
Other fuel equipment and wood uses retain their existing behavior. No pulp,
cellulose or fibre recipe is introduced. The grinder is presently map-placed in
Wizard Boy; its construction and broader-map acquisition remain undefined.

| Chain | Game conversion |
| --- | --- |
| Acid precursor | 2 hydrogen + 2 chlorine -> 1 hydrogen chloride; 1 hydrogen chloride + 5 water -> 5 hydrochloric acid |
| Crude gelatin | 4 collagen + 1 hydrochloric acid, digestive protease or fruit protease -> 5 unpurified gelatin |
| Purification | Centrifuge 5 unpurified gelatin -> 4 purified gelatin |
| Solid gelatin | 4 purified gelatin + 1 water or purified ethanol -> 5 solid gelatin |
| Blood separation | Centrifuge 10 blood -> 6 plasma + 3 red-cell reagent + 1 white-cell reagent |
| Salt separation | Centrifuge salt -> equal sodium/chlorine game yields |
| Polypropylene | 2 propylene -> 25 solid units at a heated bench; retains 10 titaniumchloride, 5 borontrifluoride, 5 aluminumchloride |
| Engine fuel | 9 gasoline + 1 purified ethanol -> 10 liquid enginefuel units |
| Butyl rubber | 10 isobutylene + 1 aluminum chloride -> 5 solid butyl rubber |

Gelatin supports all three treatments with both finishing solvents. Its yields
and the 6:3:1 blood split are deterministic game abstractions. Plasma proteins
are not substituted for digestive proteases. The fruit reagent is Fruit Protease
rather than collagenase: [IUBMB classifies papain as a papaya protease](https://iubmb.qmul.ac.uk/enzyme/EC3/4/22/2.html).

The centrifuge recovers all blood fractions instead of randomly choosing one.
Unknown inputs remain intact, output is limited by collector capacity, and lost
power/collector preserves inputs. The largest reagent selects the separation
recipe. Salt fractions can react again during ordinary automatic mixing; transfer
them into an inert bench when using them as elemental feedstocks.

The 9:1 blend uses the existing purified ethanol ID. Every internal engine already
accepting gasoline gains the blend at the same consumption/power behavior.
Ordinary gasoline and other existing fuels retain their paths. The blend inherits
gasoline's toxicity/fire-contact behavior. Diesel-only engines do not gain it.

The earlier processing phase restores the calcium/wood-processing products and
distinguishes liquid titanium tetrachloride from solid titanium trichloride.
Its decisions are in [Controlled processing](chemistry-processing.md). Isobutylene
uses 4 carbon + 8 hydrogen; the issue's C4H10O recipe describes the existing
isobutanol recipe. Sodium hydroxide uses 1 sodium + 1 hydrogen + 1 oxygen.
Other existing yields remain unchanged. Hydrogen sulfites remains a named game
abstraction rather than a neutral-compound synthesis claim.

## Verification limits

tests/chemistry/README.md documents production-method checks, mutations and
adapters. They do not prove menu clicks, full crop growth, every map's progression,
power-network integration, syringe collection or production-server behavior.
Existing power/crafting checks run separately in required CI. These tests resolve
the changed procedures without needing graphical captures under project policy.
