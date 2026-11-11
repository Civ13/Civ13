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
