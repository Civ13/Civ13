# Player-facing sprite audit

This audit starts from merged master `4e79acac9c80ba0ba3b2edef3d050bb45590d41b` and inventories **8,725** compiled `/obj/item`, `/obj/structure`, and `/obj/machinery` types. BYOND resolves inherited defaults before they are read; source text guesses are not used for inheritance. Initially **416** defaults did not resolve to a state in their icon resource. The ten confirmed repairs below reduce that to **406**.

## Confirmed obtainable repairs

| Type | Obtainability evidence | Repair |
| --- | --- | --- |
| `/obj/item/weapon/reagent_containers/food/snacks/grown/cinchona` | `code/game/objects/structures/wild.dm`, cinchona bush `attackby()` harvest; `code/modules/reagents/reagent_containers/glass.dm` grinds it into quinine | Original 32px leafy bark sprig in `icons/obj/food/cinchona.dmi`; removed nonexistent `cinchona_inhand` |
| `/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pu/ppu8` | `code/modules/1713/weapons/guns/mg/lmg.dm`, DTM constructor; scope removal puts item on turf | Existing `ppu8` in `icons/obj/guns/parts.dmi` instead of inherited `gun_att.dmi` |
| `/obj/item/weapon/attachment/scope/adjustable/sniper_scope/m84` | `code/modules/1713/weapons/guns/bolt-action.dm`, rifle constructor and scope removal | Existing `m84` in `parts.dmi` |
| `/obj/item/weapon/attachment/scope/adjustable/sniper_scope/elcan/arid` | `code/modules/1713/weapons/guns/mg/smg.dm`, weapon constructor and scope removal | Existing `elcan_arid` in `parts.dmi` |
| `/obj/item/weapon/attachment/scope/adjustable/sniper_scope/elcan/winter` | Same constructor/removal path | Existing `elcan_winter` in `parts.dmi` |
| `/obj/item/weapon/attachment/scope/adjustable/sniper_scope/vortex_viper` | Bolt-action, semiautomatic and SMG constructors and scope removal | Existing `vortex_viper` in `parts.dmi` |
| `/obj/item/clothing/head/wolfpelt/white` | Material recipe files, including `material_recipes_carib.txt`; weaving unlock in `research_node.dm` | Adapted existing wolfpelt world sprite; worn `whitewolfpelt` already exists in `icons/mob/head.dmi` |
| `/obj/item/weapon/shield/chitin` | `config/crafting/material_recipes_crustacean.txt`, chitin buckler recipe | Original plated buckler world sprite; existing hand/back graphics preserved |
| `/obj/item/weapon/shield/chitin/large` | Same file, chitin shield recipe | Original taller plated shield world sprite; existing hand/back graphics preserved |

| `/obj/structure/farming/plant/herbs` | `code/game/objects/farming.dm` herb seed and healing-herb planting paths | Correct initial `herbs_grow1` typo to existing `herbs-grow1`; growth mechanics unchanged |

## New-item coverage

The **23-type** required manifest covers all compiled material tool-head variants and the handle, the resource sieve, mining drill, both healing-herb stacks, and the ten repairs. Every covered initial state must resolve in BYOND, have legal 1/4/8-direction metadata and positive frame counts, and contain visible pixels in every declared frame. Current car-workshop implementation is owned separately; the owner was given verified existing `workbench` and `bullet_press` state options and remains responsible for its new type. The medicine owner confirmed its changes introduce fluid reagent behavior rather than additional item types.

For future obtainable types, add static-default types to `tests/sprites/required-types.json`; test dynamic constructors/overlays separately where initial defaults cannot establish rendering. Reusing an existing state is acceptable. A metadata entry with transparent frames is not sufficient.

## Remaining candidates and exclusions

[`sprite-candidates.tsv`](sprite-candidates.tsv) records all **407 remaining initial-default candidates**, declaration locations and representative source/map/recipe references. They are **not 407 confirmed invisible items**. A referenced type can be an abstract parent, a WIP map entry, an intentional invisible object, or an object with runtime rendering. References are lexical examples and do not prove reachability or inherited assignment locations.

Reviewed constructor exclusions include fur boots (`fur1..fur4`), dried octopus (`octopus_rings`) and small clay pots (`smallclaypot1..2`). Custom bottles/glasses and gallon jugs/cartons compose label/fluid overlays; their absent base states need separate composite appearance review. Other vehicle/frame defaults, map overrides, machinery runtime states, food variants, papers/stamps, and obsolete/WIP types remain untriaged. No blanket changes were made to these families.

This pass checks world/default sprites. It does not exhaustively validate every in-hand/worn state, material recolor, overlay, damage animation, map-local override, era unlock or live server appearance. Actual DMI pixels were inspected locally; game capture was unnecessary for these resource/default repairs. No production deployment occurred.

## Reproduce

Use BYOND **516.1681** and Python with Pillow (CI installs `python3-pil`). On Windows use a verified full Python executable path.

```text
<python> tests/sprites/run.py --byond-bin <BYOND-bin> --output <temporary>/sprites.json
<python> tests/sprites/run.py --byond-bin <BYOND-bin> --output <temporary>/negative.json --negative-control
<python> tests/sprites/report.py <temporary>/sprites.json <temporary>/candidates.tsv
```

The isolated fixture removes map inclusion and normal world/global-controller startup, copies required name data to temporary storage, reads compiled initial vars and `icon_states()`, closes its port and rejects reopening, and shuts down. It creates no item instances and invokes no live Topic/HTTP/RCON operation. A temporary DreamDaemon process is still required. The wrong-resource control restores the original PPU-8 defect only in a generated source copy and must be rejected. Generated source/compiler outputs and temporary runtime storage are cleaned in `finally`; preexisting probe files are protected. JSON evidence records the commit and tracked dirty state, so dirty results must not be presented as exact committed-head proof.

## Asset provenance

- `cinchona.dmi`: original hand-placed pixels; reproducible with `tests/sprites/create_cinchona.py`. No AI or third-party source artwork.
- `crafted_item_repairs.dmi`: original chitin shield pixels and recolored `icons/obj/clothing/hats.dmi` state `wolfpelt` from this repository at the audit baseline; reproducible with `tests/sprites/create_crafted_repairs.py`.
- Five optics: unmodified existing `icons/obj/guns/parts.dmi` sprites. Their existing repository attribution/license remains intact.
- New/adapted assets and scripts are distributed under Civ13's existing AGPL-3.0 license. No Pocket Stronghold assets were needed or imported; its third-party rights were therefore not implicated.
