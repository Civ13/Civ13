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
  `tgui/src/interfaces/common/Connections.tsx` is based on tgstation's, from
  `tgstation/tgstation@bacb22efd80de34f9b992ec3c731a1321147119e` (AGPL-3.0,
  see `tgui/THIRD_PARTY.md`). `index.jsx` and `VariableMenu.jsx` have small
  Civ13 changes for variable setter nodes; the other scripts are unchanged.
  `WiremodCircuit.tsx`, `backend.ts`, `assets.ts` and `layouts/` are the Civ13
  adapters around it.
- `icons/obj/devices/circuitry_n_data.dmi` and `icons/obj/science/circuits.dmi`
  are tgstation's files at the same revision, CC BY-SA 3.0; see the
  `.LICENSE.md` file beside each.

tgstation's history is not part of this repository. Shells other than the
compact remote, hardware integrations, admin components and the component
printer are not ported.

## What is here

- `datatypes/` - one file per datatype (any, number, string, boolean, signal,
  list, assoc list, option, entity), each a `/datum/circuit_datatype` subtype,
  and `_datatype.dm` with the base type and the registry built from the subtypes.
- `core/port.dm` - ports. A port holds only null, a finite number, text up to
  `PORT_MAX_STRING_LENGTH` bytes, a flat list of up to
  `CIRCUIT_MAX_LIST_LENGTH` numbers and texts, an associative list of up to
  `CIRCUIT_MAX_ASSOC_ENTRIES` text-keyed plain values, or the weak reference of
  a thing in the world. It never holds a game object.
- `core/component.dm` - `/obj/item/circuit_component`, the base component.
- `core/operator.dm` - `/obj/item/circuit_component/operator`, the base of the
  components that work a Result out of inputs A and B.
- `core/integrated_circuit.dm` - `/obj/item/integrated_circuit`: the component
  list, the execution queue, the continuation queue used by list loops, and
  the two lists of component types.
- `core/circuit_ui.dm` - the editor window: who may use it, the data it shows,
  its actions and its refreshes.
- `core/variables.dm` - circuit variables and their getter, setter and
  triggered setter nodes; list and associative variables have setters too.
- `core/world.dm` - the shell-only anchor and the helpers that read a place's
  contents or air, wrap effects in bounds, and keep a loose circuit inert.
- `core/speech_hooks.dm` - the speech and radio registries, called from
  `code/game/mob/living/say.dm` and `radio_broadcast()` in `code/modules/1713/`.
- `components/` - math, list, string, entity, sensor, action and utility
  components. Each has a `desc`, which is what the editor's info button shows.
- `shell/circuit_shell.dm` - `/obj/item/circuit_shell`, the base item that holds
  one integrated circuit. An integrated circuit goes in by hand and a screwdriver
  takes it out.
- `shell/compact_remote.dm` - `/obj/item/circuit_shell/compact_remote`, a handheld
  remote that adds its signal source to the integrated circuit inserted into it.
- Constants are in `code/__defines/wiremod.dm`.

## How it is put together

- **Datatypes.** Each `/datum/circuit_datatype` subtype in `datatypes/` is one
  datatype and holds everything about it: what a wire may deliver to it
  (`convert`), how a typed value is read (`parse_manual`) and the message for
  one that cannot be, which outputs it accepts, its colour in the editor and
  what the editor is shown of a value (`ui_value`, `ui_data`). Defining a
  subtype with a `datatype` name registers it (`wiremod_datatypes()`); the
  editor code names no datatype's colour or rules. The colours are
  tgstation's: any blue, number green, string orange, signal teal, boolean
  red ("bad"), list white, assoc list label, option violet, entity purple.
  An associative list is its own type, not a flat list with keys. Two lists
  stay explicit on purpose: `CIRCUIT_USER_TYPES`, the types a player may type
  a value for, and `CIRCUIT_VARIABLE_TYPES`, the types a variable may have.
- **Entities.** An entity is a person or an object (`/atom/movable`). A port or
  variable holds its `/datum/weakref`, never the thing: the handle does not
  keep it alive and stops resolving once it is deleted. A port holding one also
  registers with `GLOB.destroyed_event` and empties itself when the thing is
  deleted (`/datum/port/proc/hold` is the one place a port's value changes and
  pairs the registering with the letting go); nothing is run from that
  deletion. An entity reads as its name in a text input and in the editor,
  cannot be typed, is never put in a list and is not saved. A component hands
  a port `WEAKREF(thing)`.
- **Marking.** tgstation marks a thing with a multitool and presses the entity
  input. Here pressing an entity (or untyped) input marks the item in the
  player's other hand, or the player when no other item is held; marking the
  same thing again clears the input. The request carries only a flag, so a
  player can mark only what they hold or themselves.
- **Lists on ports are never changed in place.** `set_output()` stores a copy of
  what a component hands it, and a component that wants a different list builds
  a new one. A wire can therefore pass the same list to a list or untyped input
  without checking and copying it again (`/datum/port/input/proc/receive_from`).
  A flat list and an associative list are not interchangeable. Every other
  value is converted on every hop.
- **Components are named by `circuit_id`.** A circuit numbers each component as
  it goes in and never gives a number out twice, so a request that arrives
  after its component was removed reaches nothing. Port names sent to the
  editor (`input-<id>-<position>`) are built from the same number. The upstream
  editor sends list positions; `WiremodCircuit.tsx` turns each into the id of
  the component shown at that position.
- **Editor actions are one table.** `ui_action_table()` in `core/circuit_ui.dm`
  maps each action to its handler proc (`act_<action>`) and the fields it may
  carry. The lists the window transport asks for and the dispatch in `ui_act()`
  are all read from it. To add an action, add one row and one proc.
- **Component types are in one of two lists** in `core/integrated_circuit.dm`:
  `wiremod_available_components()`, kept by hand, is what the editor offers
  and all `print_component` will make; `wiremod_unlisted_components()` names
  every other type with the reason. The tests fail for a type in neither.
- **Two-input components** derive from `/obj/item/circuit_component/operator`:
  set `operand_type`, `result_type` and, for a choice of operations,
  `operations`, then write `operate(left, right, chosen)`.
- **Triggering is explicit.** A component that has a Trigger input writes only
  when that signal arrives. A pure calculation without one writes when any of
  its inputs changes and also fires its `Triggered` output. Filter List and
  For Each walk one entry per trigger, using the circuit's continuation queue
  so the downstream chain can settle before the next entry.
- **World-facing components use the shell.** A loose circuit has no anchor, so
  sensors report nothing and actions do nothing; the helpers in `core/world.dm`
  are the only path to the map. A Voice Activator also hears speech and radio
  traffic near the shell, and a Radio component uses Civ13's radio network; a
  radio message never tells the circuit who originally spoke.
- **Editor refreshes are spaced out.** A circuit that runs sends its open
  editors the new state at once, then at most once every
  `CIRCUIT_UI_REFRESH_INTERVAL` deciseconds; the last state is always sent.

## How it plays

Use an integrated circuit in hand to open the editor. Drag components in from
the component menu, type values into unconnected inputs, pick an operation from
the dropdown on operation inputs, and drag from an output to an input to connect
them. The (i) button on a component shows what it does and lists its ports.
An input takes one connection. Variables are made in the variable menu and
read and written through getter, setter or triggered setter nodes; setters work
for flat and associative variables too. Lists come from String Split and the
list literal components, and pass between the list components. Pressing a
signal input in the editor fires it by hand.

World-facing components work from the shell the circuit is installed in. A
loose circuit cannot see, hear, speak, light, print or transmit: those
components have no anchor. Install the circuit in a shell before wiring a
sensor, a Voice Activator, a Radio or Pathfinder. A Voice Activator fires on
nearby speech or on a radio message heard at the shell; a Radio sends through
Civ13's radio network and reports only the message, not who spoke it.

A compact remote is empty when crafted. Use an integrated circuit on it to
insert one; the remote attaches its own signal source to that circuit. Use the
remote in hand to fire the circuit and Alt-click it to edit the circuit. Use a
screwdriver on the remote to take the circuit out again; the signal source stays
with the remote and is attached when another circuit goes in. Its User output is
the presser as an entity; wired into a text input it gives their visible name.
The Direction component gives the compass direction and distance to an entity
within `CIRCUIT_DIRECTION_RANGE` tiles of the circuit.

Not ported, because Civ13 has no matching mechanic: ID Access Reader, ID
Getter and ID Info Reader (no card access data on ports), Get Column, Index
Table and Select Query (no USB database connection), MMI, NTNet Receiver and
NTNet Transmitter (no NTnet), Access Checker (no ID card signal), Pull (only
Drone shells) and MOD Action (no MOD suit interface). Module is deferred until
the module shell exists.

## Limits

- `CIRCUIT_MAX_COMPONENTS` components and `CIRCUIT_MAX_VARIABLES` variables per
  circuit. A port holds at most `PORT_MAX_STRING_LENGTH` bytes of text,
  `CIRCUIT_MAX_LIST_LENGTH` flat list entries and `CIRCUIT_MAX_ASSOC_ENTRIES`
  associative entries.
- One propagation may queue `CIRCUIT_MAX_EXECUTIONS` component calls. Past that
  the rest is dropped and the circuit overloads: it tells its holder and ignores
  inputs for `CIRCUIT_OVERLOAD_COOLDOWN` deciseconds. This is what stops a
  feedback loop.
- The Delay component waits between `CIRCUIT_DELAY_MIN` and `CIRCUIT_DELAY_MAX`
  seconds and holds one timer; retriggering restarts it. Sound and Speech have
  a `CIRCUIT_SOUND_COOLDOWN`/`CIRCUIT_SPEECH_COOLDOWN` of ten deciseconds.
- Binary Conversion reads and writes `CIRCUIT_BINARY_BITS` bits, least
  significant first. An out-of-range or non-whole number gives no bits.
- Filter List and For Each take at most `CIRCUIT_MAX_LOOP_STEPS` entries in one
  run. Direction and the near-field sensors look `CIRCUIT_DIRECTION_RANGE`
  tiles from the shell; a View Sensor reports at most
  `CIRCUIT_MAX_VIEW_ENTITIES` entities. Pathfinder searches at most
  `CIRCUIT_MAX_PATH_STEPS` steps and `CIRCUIT_MAX_PATH_NODES` tiles.
- A component made in the editor is deleted when it is removed, so the editor
  cannot be used to produce items. A component inserted by hand goes back to the
  hand.
- A circuit takes `CIRCUIT_MAX_COMPONENT_ID` insertions over its whole life.
- Circuits, components and remotes have `should_save = FALSE`: the port graph is
  live state and is not written to persistent saves.

## Availability

`/obj/item/integrated_circuit` and `/obj/item/circuit_shell/compact_remote` are
crafted from electronics (`config/crafting/material_recipes_global.txt`). A
crafted remote ships empty and needs an integrated circuit inserted before it
can send signals. Components are made only in a circuit's editor;
`code/game/mob/crafting_atlas_admin.dm` keeps `/obj/item/circuit_component` out
of the public Crafting Atlas.

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
- `cd tgui && CHROMIUM_PATH=<chromium> node scripts/wiremod-browser-smoke.mjs` -
  real clicks on the production bundle in Chromium: the operation dropdown
  opens above the board and sends the chosen operation, the info button shows
  the description and ports, an entity input sends a mark request. It is part
  of `npm run test:browser`. `WIREMOD_SCREENSHOT_DIR=<dir>` saves screenshots.

tgui-core draws Dropdown menus and Tooltips in a portal at the end of `<body>`.
`tgui/src/styles.scss` loads its `Floating` stylesheet and puts `.Floating`
above every layer a window stacks; without that the operation menu opened
underneath the full-window editor and nothing could be picked.

## Clocked Processor (draft v1)

Install an integrated circuit in its shell and add a **Clocked Processor**.
Enter assembly into **Program** (separate instructions with semicolons or
newlines), then pulse **Load**. Example:

```text
ADDR 524287; IN; PUT; SET 0; GET; OUT; HALT
```

Set **Input** to 42 and pulse **Run**: the program writes 42 to the last
addressable byte, reads it back, updates **Value**, and pulses **Emit**. A
further pulse halts it. Connect the numeric output to a consumer's data port
and **Emit** to the consumer's signal port. Input/Program updates never execute
anything. Pulse **Step** for one instruction, **Run** for up to 16, or **Reset**
to clear registers and RAM while retaining the loaded program. **Status**
reports ready, output, halted, no program, invalid program, budget, or RAM limit.
No work is scheduled automatically; a later signal can resume a yielded slice.

The program has at most 256 instructions, with unsigned decimal operands,
case-insensitive mnemonics and one-based jump targets. A successful Load
replaces the program and resets it; an invalid Load preserves the previous
program, registers and RAM. The accumulator is unsigned 24-bit and the
address register is unsigned 19-bit. Supported instructions:

| Instruction | Meaning |
| --- | --- |
| `SET n` / `ADD n` | Set the accumulator or add modulo 2²⁴. |
| `ADDR n` / `NEXT n` | Set the address register or advance it modulo 524,288. |
| `GET` / `PUT` | Read a byte into the accumulator or write its low byte. |
| `IN` | Sample the numeric port, truncating to 0–16,777,215 (zero if unset). |
| `OUT` | Publish the accumulator and yield after one Emit pulse. |
| `JMP n` / `JZ n` | Jump unconditionally or when the accumulator is zero. |
| `NOP` / `HALT` | Spend one instruction or halt. End-of-program also halts. |

Each CPU has private integrated RAM, not a separately wireable memory chip
or address bus. Its 512 KiB address space is backed by lazy 256-byte pages
(three guest bytes per numeric slot; writes of zero to unallocated pages do
not allocate). The one board in a shell shares a 512 KiB **allocation** budget
across its CPUs; allocations are also capped at 8 MiB across all CPUs in the
world. This is guest capacity, **not** DM heap consumption. Reset, loading a
valid replacement, unmounting the board, or removing/destroying a CPU releases
its pages; unmount additionally resets the CPU, and removing the component
also forgets the program. Nothing is saved across world restarts.

Each distinct `world.time` window allows up to 64 guest instructions or
one Load/Reset per board, and 512 instruction units world-wide (Load/Reset
cost 64 each). A refused Run/Step does not requeue itself; Load/Reset pulses
that exceed the limit are ignored. Bounds apply even to a Wiremod feedback
loop, but first-come dispatch is not guaranteed fairness under contention.
There are no arbitrary engine calls, network, files, or entity access from
assembly; use ordinary Wiremod components for physical input and output.
Autonomous or fair scheduling, a 1 MHz rate, measured heap cost, and
real client operation are not part of this draft.
