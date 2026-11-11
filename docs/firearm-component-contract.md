# Firearm component contract (issue #4443, phase 0)

The schema and invariants that phases 2 to 6 implement. It extends the existing
gun configuration (`code/modules/1713/gunsmithing/gun_configuration.dm`: slots,
compatibility, timed work, `gun_work_busy`, unload checks, ergonomics
recomputation) instead of adding a second attachment or repair system.

## Identifiers

| ID | Example | Meaning |
| --- | --- | --- |
| family | `ak` | a platform whose parts interchange |
| component | `ak/barrel/762x39` | one recoverable part kind, owned by one family |
| slot | `barrel` | one of `action`, `barrel`, `feed`, `furniture`, plus the existing `optic`, `muzzle`, `underbarrel` |
| feed interface | `ak_mag/762x39` | which magazines a feed part accepts |
| conversion set | `ak/762x39-545x39` | an explicitly supported caliber change (barrel + feed together) |
| caliber | `a762x39` | the existing casing caliber string, unchanged |

IDs are text, stable and never reused. Each registry entry carries
`schema_version`. Legacy gun typepaths stay as presets: a preset names the
family and the component IDs it is built from, and the gun keeps its typepath.

## Physical state

- The gun is the core (receiver/platform). It owns at most one part per slot.
- A part is an item with `component_id`, `condition` and `max_condition`. Only
  parts that give players a decision are modelled: no screws or springs.
- Compatibility is family + slot + interface. Matching caliber alone never makes
  a part fit. A caliber change needs a listed conversion set.
- A gun missing a required part (action, barrel, feed) cannot fire and says why.

## Derived stats

- Stats are rebuilt from immutable definitions plus part condition, only when a
  part is installed, removed or its condition crosses a threshold. No inventory
  scan per shot or per tick.
- Firing takes a snapshot (damage, accuracy, caliber, condition effects); a part
  swap mid-flight never changes a fired round.

## Work and transactions

- Field strip: reversible, recovers allowed parts with identity and condition,
  needs the gun unloaded, uses the existing `wait_for_configuration` guards.
- Workshop work: internal slots, at a gun repair bench (`/obj/structure/repair/gun`).
- Dismantle: destructive salvage, shows what is lost and asks to confirm. Never
  the same verb as removal.
- Every assembly/disassembly checks parts, tools, bench and research, waits,
  rechecks ownership and location, then moves or consumes each item exactly once.
  Movement, damage, power loss or another action cancels it with nothing consumed.
- No sequence of assemble/disassemble/salvage/repair creates material, resets
  wear or yields more than its inputs.

## Pilot: AK family (phase 2)

`code/modules/1713/gunsmithing/firearm_components.dm` implements the contract
for the AKM and AK-74 lines (11 types, `migration: modular` in the coverage
manifest):

| Slot | Parts | Work |
| --- | --- | --- |
| action | `ak/action` | firearm bench |
| barrel | `ak/barrel/762x39`, `ak/barrel/545x39` | firearm bench |
| feed | `ak/feed/762x39`, `ak/feed/545x39` (magazine lists) | by hand |
| furniture | `ak/furniture/fixed` (handling x1), `ak/furniture/folding` (x0.95) | by hand |

- Installed parts are data on the gun (`firearm_part_ids`, `firearm_part_condition`),
  built lazily from the type's preset. A removed part is a `/obj/item/weapon/gun_component`.
- Action, barrel and feed are required. A barrel and feed of different calibers
  block firing; a matching pair sets the gun's caliber and magazines (the
  7.62/5.45 conversion set). No stock handles at x0.75 but still fires.
- The barrel loses 1/1000 per shot and blocks firing at 0; condition travels
  with the part. Handling derives from the type's compiled ergonomics, so
  reapplying or loading never compounds.
- Unknown saved ids stay recorded and block firing rather than being deleted.

### Factory route (phase 3)

`config/crafting/factory_recipes.txt` makes every AK part and a bare **AK
receiver** (`/obj/item/weapon/gun/projectile/submachinegun/ak74/receiver`, empty
preset) in fabricators, all gated by **Automatic Weapons**:

| Recipe | Inputs | Time | Tier |
| --- | --- | --- | --- |
| AK receiver | 6 steel | 150 | 2 |
| AK bolt carrier group | 3 steel | 120 | 2 |
| AK barrel 7.62x39mm / 5.45x39mm | 3 steel | 100 | 2 |
| AK magazine well 7.62x39mm / 5.45x39mm | 2 steel | 60 | 1 |
| AK fixed stock | 2 wood | 40 | 1 |
| AK folding stock | 2 steel | 60 | 1 |

A full rifle costs 14 steel (plus 2 wood or 2 more steel) and a firearm bench to
fit the internals. The receiver names itself "AK rifle (caliber)" once a barrel
is fitted. Fabricators keep their existing input buffering, power pauses and
exactly-once consumption (`tests/factory_automation/fabricators_probe.dm`).

### Family expansion (phase 5)

The AK family adds `ak/barrel/556x45` and `ak/feed/556x45` (AK-101 magazines)
and covers the AK-100 series: AK-101/102 (5.56x45mm), AK-103/104 (7.62x39mm)
and AK-105 (5.45x39mm), all with the folding stock. An AK receiver can now be
built in any of the three calibers.

The **AR family** (`ar`) covers the M16 line (M16A1, AR-15, M16A2, M16A4 and
their variants), the XM177E2/M4/M4 MWS carbines and the C7/C8. The Service
Rifle takes its own magazines and stays a fixed design.

| Slot | Parts | Work |
| --- | --- | --- |
| action | `ar/action` | firearm bench |
| barrel | `ar/barrel/556x45` | firearm bench |
| feed | `ar/feed/556x45` (M16 and AR-15 magazines) | by hand |
| furniture | `ar/furniture/fixed` (x1, rifles), `ar/furniture/collapsible` (x0.95, carbines) | by hand |

Parts of one family never fit the other. Factory recipes, also gated by
Automatic Weapons: AR receiver (`m16/receiver`, 5 steel, 150, tier 2), AR bolt
carrier group (3 steel, 120, tier 2), AR barrel (3 steel, 100, tier 2), AR
magazine well (2 steel, 60, tier 1), AR fixed and collapsible stocks (2 plastic,
40 and 60, tier 1), plus the AK 5.56x45mm barrel and magazine well. A bare
receiver names itself "AR rifle (5.56x45mm)" once a barrel is fitted.

The **Mauser family** (`mauser`) is the first bolt-action family: Gewehr 98,
Karabiner 98a and 98k (including the Chinese and sniper versions), Mauser
M1890, M1893, M1893 (Ottoman) and M1903. Its feed part is the fixed internal
magazine and clip guide, so it sets the stripper clips the rifle takes and the
loose round an ammo box must hold (`ammo_type`) instead of detachable
magazines. Barrels and magazines come in 7.92x57mm, 7.65x53mm and 7x57mm, so a
Kar98k can be rebarrelled to 7.65x53mm at a bench. One wooden stock (x1) fits
every Mauser, so existing rifles keep their handling.

Mauser recipes are gated by **Cartridge Firearms** at tier 1: receiver
(`gewehr98/receiver`, 4 steel, 120), bolt (2 steel, 90), each barrel (3 steel,
100), each magazine (1 steel, 50) and stock (3 wood, 40). A bare receiver names
itself "Mauser rifle (caliber)" once a barrel is fitted.

The **Mosin family** (`mosin`: Mosin M1891, 91/30 and its sniper version,
7.62x54mmR) and the **Arisaka family** (`arisaka`: Types 30, 35, 38, 97 sniper
and 99 with its sniper and bayonet versions) follow the Mauser pattern. Arisaka
barrels and magazines come in 6.5x50mm and 7.7x58mm, so a Type 38 can take Type
99 clips after a bench conversion. The sawn-off Obrez keeps its own weight,
size and damage and stays fixed, as does the training Arisaka. The Type 38 now
spawns with 6.5x50mm rounds; it used to inherit 7.62x54mmR loose rounds from
the base bolt-action rifle. Both families' recipes match the Mauser ones (bare
`mosin/receiver` and `arisaka38/receiver`, Cartridge Firearms, tier 1).

Every modular gun gets the "Rifle Parts" verb from `/obj/item/weapon/gun/New()`
when it has a family, so fixed designs never show it.

### Parts panel and salvage (phase 6)

The "Rifle Parts" verb opens a panel (`firearm_panel_html`) listing whether the
gun fires or why not, its cartridge, handling and accepted magazines or clips,
each slot's part and condition with where it can be worked (by hand or at a
firearm bench) and a Remove link, and every loose part the user carries. A
carried part of the same family shows a preview of the gun with that part in
its slot: handling before and after, cartridge, and whether it would fire.
The preview runs the pure `firearm_assembly_block`, `firearm_assembly_handling`
and `firearm_assembly_caliber` procs on copies of the part lists, so it never
changes the gun. Fit is offered for the part in the active hand. Each link is
only a request: `firearm_panel_act` checks the user holds the gun, the part is
carried by the user and the slot is real, and remove and fit then run their
usual checks.

Salvage destroys a loose part at a firearm bench and returns its factory recipe
inputs x condition x 0.5, rounded to the nearest unit (a full AK barrel, 3
steel, returns 2; a worn-out one returns nothing). It is a separate action from
removal: the panel's Salvage link first shows "Salvaging destroys X (N%) and
returns ..." with a Confirm link, and hitting the bench with a part asks the
same question. A part with no recipe returns nothing. Salvage never returns
more than the part cost.

Not yet: the remaining families (Enfield, Springfield and other bolt-action
rifles, pistols, revolvers, shotguns, machine guns and other rifles).

## Ammunition and armor

Phase 1 (#4565) made armor monotonic and nonnegative and AP/HP idempotent
(`docs/firearm-armor-impact.md`). Phase 4 adds per-caliber profiles (damage
budget, penetration tier, range band, recoil, cover passage) and a single
impact result: coverage, then armor, then bounded residual damage, then
nonnegative wear, then secondary effects, then passage. Body armor and
structural cover stay separate.

## Persistence

- Saved component state is versioned. A legacy gun loads as its preset once;
  a repeated load grants no parts, reapplies no multipliers, resets no wear and
  duplicates no rounds.
- Existing identity is kept: health, attachments, loaded order, chambered round,
  spent flags, name, serial, blueprint choices.
- An unknown component ID loads as an inert part with a diagnostic, never deleted.
- The system stays opt-in on Persistence until all families and partial
  assemblies pass save/load fixtures.

## Coverage

`docs/firearm-coverage.json` lists every gun type with category and scope; the
issue is complete when every `modern` entry's `migration` is no longer
`pending` and has tests (`tests/firearm_coverage/README.md`).
