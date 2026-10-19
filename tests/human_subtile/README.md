# Opt-in human sub-tile adapter

Source-only integration stacked from the separately verified native primitive
at `c605363a11050dbf67fe4820cc8cc4587c9cf97c` (Civ13 base `cc03b199`).
No compiler, daemon or client has been launched for this integration during
preparation. Native, real-client and visual acceptance remain pending.

The opt-in is disabled by default. `set_human_subtile(TRUE)` enables it for an
eligible ordinary human. Client Move retains its existing admission checks and
once-per-logical-input costs. Only its SelfMove physics operation is segmented
into at most eight native4px moves, retaining32x32 bounds. This is real collision
movement, not pixel offsets or glide. No production glide setting changes.

The existing cardinal cooldown arithmetic is captured before SelfMove can yield;
the adapter does not rescale it a second time afterward. Pulse times are absolute
fractions of that interval. More than one pulse may occur in an engine frame;
frame rate limits visible increments. Preserved speed means the admitted tile
interval and sustained distance/time, not identical startup arrival phase or
intermediate positions. A native timing comparison is still required.

Existing client nutrition/water/stamina/velocity rules run once per admitted
32px intent, including blocked attempts, as they did before. They are not
redefined as charges proportional to successful displacement. Existing human
and living completion bodies are shared unchanged with the ordinary path and
run once after any positive transaction displacement, including partial moves
or cancellation. Zero-displacement adapter attempts do not emit those completion
notifications. Native turf/area/Cross callbacks remain engine-owned; the fixture
counts actual Entered and shoe movement hooks instead of manually replaying them.

A one-use pulse records the exact actor, destination, direction and starting
position. Only the movable's native seam consumes it. It cannot be reused by a
reentrant Move or borrowed for another destination. Contexts are released on
success, obstruction, cancellation, error, deletion and client/body replacement.
The living Move third flag is not repurposed. Identity, permission and physical
position are rechecked between yields; intentional external teleports cancel the
old transaction instead of making its next pulse relative to the new position.

## Supported slice and refusal rules

The adapter currently supports cardinal, conscious, ordinary walking/running
humans, including the existing terrain/trait cooldown calculations. Pulling,
being pulled, grabs/restraints/pinning, riding, buckles/vehicles, drones, control
objects, incorporeal movement, prone/crouched/lying movement, stationary weapons,
cannons and football use their legacy route only while tile-aligned. At an
adapter-owned offset, unsupported transitions and disabling the adapter are
refused with the position retained. There is no silent snap or tile fallback.
The first slice does not convert diagonal, vehicle or multi-z movement, combat,
projectile geometry, roofs or lighting to a new spatial model.

The actual click-direction check is `target.Adjacent(user)`: the fixture checks
near/far targets at offsets0/4/28 and after crossing the anchor. Reverse
`user.Adjacent(target)` can include the user's overlapped turfs and extend reach;
the fixture records that distinction rather than claiming every interaction is
unchanged. Native overlap also changes turf contents membership. No general
combat or projectile equivalence follows from these checks.

## Actual serializer policy

Adapter positions use a five-integer anchored capsule (`x,y,z,sx,sy`). Runtime
enable, owner/context/import flags and deadlines are explicitly excluded by
`persistence_runtime_var`; `tmp` alone is not relied upon. Saving a sleeping
transaction cancels it and snapshots its completed physical position; saving an
active pulse or an offset actor with unsupported links fails closed.

At the exact Load_Entry boundary, capsule field presence is captured before any
assignments. Only owned entries suppress raw step fields, regardless of saved
field order. No-capsule legacy human entries retain their prior raw-offset
behavior. Malformed/null owned capsules fail instead of taking a legacy fallback.

The post-load hook validates exact anchor/offset/bounds and checks the actual
destination footprint through CanPass before one native Move. CanPass callbacks
can have side effects and are not described as pure. A blocked destination is
rejected before native placement; the fixture checks the initial replacement
position and runtime clocks remain intact. No forced loc assignment restores
offsets. Facing is preserved. The actual serializer preserves paid nested
contents; the fixture exercises BuildVarDirectory, disk reopen, Load_Entry and
the normal caller's explicit after_load phase.

Only unlinked ordinary-body offset restoration is in this slice. The restored
adapter is off and no worker is replayed; a retained offset refuses ordinary
input until explicit re-enabling. Whole-world simultaneous collision preflight,
arbitrary side-effecting CanPass rollback and all vehicle graphs are not newly
guaranteed here. The earlier standalone relative-first-read savefile issue and
its accepted absolute-entry proof remain separate retained evidence.

## Source checks and fixture interfaces

```powershell
py -3 tests/human_subtile/test_sources.py
```

These offline checks cover source isolation, legacy cooldown tail byte parity,
trait arithmetic, absolute scheduling, one-use guards, cleanup, owned-import
ordering and actual-codec fixture wiring. They do not compile or execute DM.

Root owns the reviewed source/assets freezer and native/capture envelope. The
full-source DME keeps real human constructors, movement, turf callbacks and the
actual serializer; startup/global initialization and map includes are isolated.
Only public checked-in config/resources are used. The interfaces are:

- `human_subtile_fixture_initialize()` creates config, registries, observer
  events, movementMachine and a minimal metadata owner.
- `human_subtile_fixture_actor(x,y)` constructs an actual human subtype wearing
  an existing uniform, with a declared headless permission hook. For a real
  client, that hook delegates to the production client/body authority check.
- `human_subtile_fixture_headless()` has exactly42 expected assertions, including
  movement/overlap, wall/partial collision, once-only completion, cancellation,
  reentrancy/deletion, restrictions, actual serializer roundtrip/rejections,
  preserved legacy raw offsets and reach-direction checks.
- `human_subtile_fixture_client(client/C)` requires an already-attached real
  fixture actor and exercises actual client.Move for ordinary/slowfloor/Agile/
  Slowness+Gigantism/running cases plus failed-attempt cost/deadline parity. It
  returns twelve bounded result rows and executes39 assertions. It is scripted
  client.Move coverage, not OS key delivery or movementMachine scheduler proof.
- Global `human_subtile_fixture_phase` is bounded caption telemetry updated
  before each client condition/leg; it does not drive movement.

The default fixture wrapper rejects clients/Topics, closes the port, runs the
headless path, and writes `port-closed.txt`, `result.txt` and `receipt.json` with
platform-native single line endings, then disposes the world. Root may replace
only that wrapper and append its reviewed one-client admission/capture adapter.
Any compile warning/runtime/incorrect assertion or missing terminal receipt
rejects native acceptance. Actual game input, timing and visuals must be
reported separately; no publication or live activation is implied.
