# Integrated circuits (Wiremod core)

Programmable circuits modelled on tgstation's Wiremod. Ported to Civ13 by
Terrariola (GitHub `Terra1`); audited and hardened afterwards (see
`tests/wiremod`).

## Where it comes from

- The DM code in this folder is a Civ13 implementation of tgstation's Wiremod
  design (typed ports, components, shells), written against Civ13's own item,
  timer and window code. tgstation's code is AGPL-3.0, the same licence as
  Civ13.
- The editor in `tgui/src/interfaces/IntegratedCircuit/` and
  `tgui/src/interfaces/common/Connections.tsx` is tgstation's, from
  `tgstation/tgstation@bacb22efd80de34f9b992ec3c731a1321147119e`: the script
  files are unchanged and the stylesheet is adapted (AGPL-3.0, see
  `tgui/THIRD_PARTY.md`). `WiremodCircuit.tsx`, `backend.ts`,
  `assets.ts` and `layouts/` are the Civ13 adapters around it.
- `icons/obj/devices/circuitry_n_data.dmi` and `icons/obj/science/circuits.dmi`
  are tgstation's files at the same revision, CC BY-SA 3.0; see the
  `.LICENSE.md` file beside each.

tgstation's history is not part of this repository. Shells other than the
compact remote, hardware integrations, admin components and the component
printer are not ported.

## What is here

- `core/port.dm` - datatypes and ports. A port holds only null, a finite number,
  text up to `PORT_MAX_STRING_LENGTH` bytes or a list of up to
  `CIRCUIT_MAX_LIST_LENGTH` such values. It never holds a game object.
- `core/component.dm` - `/obj/item/circuit_component`, the base component.
- `core/integrated_circuit.dm` - `/obj/item/integrated_circuit`: the component
  list, the execution queue, variables and the editor window's data and actions.
- `components/` - math, list, string and delay components.
- `shell/compact_remote.dm` - `/obj/item/compact_remote`, a handheld remote with
  a built-in circuit.
- Constants are in `code/__defines/wiremod.dm`.

## How it plays

Use an integrated circuit in hand to open the editor. Drag components in from
the component menu, type values into unconnected inputs, pick an operation from
the dropdown on operation inputs, and drag from an output to an input to connect
them. An input takes one connection. Variables are made in the variable menu and
read and written through getter and setter nodes. Lists come from String Split
and pass between the list components. Pressing a signal input in the editor
fires it by hand.

The compact remote has a built-in signal source: use it in hand to fire its
circuit, Alt-click it to edit the circuit. Its User output is the presser's
visible name.

## Limits

- `CIRCUIT_MAX_COMPONENTS` components and `CIRCUIT_MAX_VARIABLES` variables per
  circuit.
- One propagation may queue `CIRCUIT_MAX_EXECUTIONS` component calls. Past that
  the rest is dropped and the circuit overloads: it tells its holder and ignores
  inputs for `CIRCUIT_OVERLOAD_COOLDOWN` deciseconds. This is what stops a
  feedback loop.
- The Delay component waits between `CIRCUIT_DELAY_MIN` and `CIRCUIT_DELAY_MAX`
  seconds and holds one timer; retriggering restarts it.
- A component made in the editor is deleted when it is removed, so the editor
  cannot be used to produce items. A component inserted by hand goes back to the
  hand.
- Circuits, components and remotes have `should_save = FALSE`: the port graph is
  live state and is not written to persistent saves.

## Availability

There is no crafting recipe, research node or map placement for
`/obj/item/integrated_circuit`, `/obj/item/circuit_component/*` or
`/obj/item/compact_remote` yet. They exist only when an admin spawns them, and
`code/game/mob/crafting_atlas_admin.dm` keeps them out of the public Crafting
Atlas until that changes.

## Tests

- `python3 -m unittest tests/wiremod/test_wiremod_core.py` - offline source
  checks (also the `wiremod` suite in `scripts/ci_baseline.py`).
- `python3 tests/wiremod/run.py --byond-bin <pinned BYOND bin>` - compiles the
  module with `tests/wiremod/probe.dm` and runs it on the engine.
- `python3 tests/ecology_spawning/run_linux.py . tests/wiremod/game_probe.dm` -
  the same module inside the whole game (no maps): real items, mobs, timers,
  qdel and the window transport, driven as an agent body's button presses.
- `cd tgui && npx vitest run src/interfaces/WiremodCircuit.test.tsx` - the editor
  adapter.
