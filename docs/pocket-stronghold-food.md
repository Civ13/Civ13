# Pocket Stronghold food sprites

Inventory for issue #3599. Source: Pocket Stronghold 13
`dwarfs/icons/items/food.dmi` at `2bfb1906a9a68f58c5e5da25383f83dd495bf138`
(39 states, all 32x32, one direction, one frame). The art is CC BY-SA 3.0, the
same terms as the Pocket Stronghold crops and bark already in Civ13; see
[the licence notice](../icons/obj/food/pocket_stronghold_food.dmi.LICENSE.md).

Rule used: import a state only where a Civ13 food that players already get
lacks its own art. Foods with working Civ13 states keep them. New artwork does
not create items, recipes or nutrient profiles, so states for foods Civ13 does
not have are left out.

## Imported

| State | Civ13 use | Before |
| --- | --- | --- |
| `intestines` | `offal/intestines` from butchering | shared the generic giblets `innards` sprite |
| `crab_meat_roasted` | `rawcrab` after oven or campfire roasting | raw crab sprite tinted orange |
| `food_ruined` | roasted crab meat once it rots | raw crab rot sprite under the tint |

Roasting uses a new optional `roasted_icon`/`roasted_icon_state`/
`roasted_rotten_icon_state` on food. Items without it keep the orange tint.
Preview: [pocket-stronghold-food.png](media/pocket-stronghold-food.png)
(actual pixels at 4x, not a gameplay screenshot).

## Kept Civ13 art (working states already exist)

`meat`, `meat_roasted`, `meat_slice`, `meat_slice_roasted` (Civ13 meat, steak,
raw cutlet, cutlet); `sausage`, `sausage_casing` (sausage, sausage casing
stack); `dough`, `dough_slice`, `dough_flat`; `salad` (tossed salad); `gyros`
(gyro); `egg`; `dwarven_stew` (stew); `food_ruined` as burnt food (Civ13
`badrecipe` keeps its sprite).

## Excluded (no matching Civ13 food)

- `crab_claw`, `crab_claw_roasted`, `crab_leg`, `crab_leg_roasted`,
  `crab_meat`, `crab_cakes`: Civ13 crabs give one generic crab meat item,
  which already has raw art. Claws, legs and crab cakes would be new items.
- `skewer`, `meat_skewer`, `meatslice1_skewer` to `meatslice4_skewer`,
  `crab_leg_skewer`, `crab_claw_skewer`, `plump_kebab`: Civ13 has no skewer
  cooking.
- `plump_slice`, `plump_n_steak`, `plump_pie`: Civ13 plump helmets are not
  sliced or cooked into dishes.
- `troll_meat`, `troll_slice`, `troll_delight`: no trolls in Civ13.
- `beer_wurst`, `allwurst`: Pocket Stronghold skillet dishes with no Civ13
  recipe.

`dwarfs/icons/items/kitchen.dmi` holds tools and containers, not food, and was
not part of this pass.

## Rebuild and verify

```text
python3 tools/art_ports/pocket_stronghold_food.py verify
python3 -m unittest discover -s tools/art_ports -p test_pocket_stronghold_food.py -v
python3 tools/art_ports/pocket_stronghold_food.py rebuild --source <PS13 checkout>/dwarfs/icons/items/food.dmi
python3 tools/art_ports/pocket_stronghold_food.py preview --output docs/media/pocket-stronghold-food.png
```
