# Opt-in human sub-tile adapter

Opt-in integration stacked from the separately verified native primitive
at `c605363a11050dbf67fe4820cc8cc4587c9cf97c` (Civ13 base `cc03b199`).
The root owner verified exact source
`c3767579b0e72035debe702ae2147c75549a7455` with BYOND516.1681:42 headless
integration assertions and39 assertions through a real connected client's
scripted `client.Move`. The private showcase adapter passed three additional
collision/restriction checks, including a measured2px partial collision; those
are separate from the public fixture's42/39 counts. Compilation had zero errors
and warnings, diagnostics were clean, and the full Windows owned-Job envelope
confirmed cleanup and an unchanged live-server baseline. Later test/docs/CI
packaging retains those production and probe bytes.

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
intermediate positions. Native comparisons passed for ordinary walking, slow
floor, Agile, Slowness+Gigantism and running: three admitted tiles per leg had
matching sustained elapsed time, final cooldown, nutrition and stamina costs.
Blocked attempts also retained matching admission costs and cooldowns.

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
  Rows also append to `client-observations.jsonl` before assertions, retaining
  bounded admission/end state if a later comparison fails. Fixture deadline
  waits recheck the actual client deadline each engine tick: one fractional
  sleep can wake early and correctly trigger the production admission guard.
- Global `human_subtile_fixture_phase` is bounded caption telemetry updated
  before each client condition/leg; it does not drive movement.

The default fixture wrapper rejects clients/Topics, closes the port, runs the
headless path, and writes `port-closed.txt`, `result.txt` and `receipt.json` with
platform-native single line endings, then disposes the world. Root may replace
only that wrapper and append its reviewed one-client admission/capture adapter.
Any compile warning/runtime/incorrect assertion or missing terminal receipt
rejects native acceptance. Actual game input, timing and visuals must be
reported separately; no publication or live activation is implied.

The connected test adapts startup, gameplay Login, HUD setup and Logout for one
isolated client. It executes production `client.Move` by script; it does not
prove OS keyboard delivery or movementMachine polling. A real DreamSeeker
recording was inspected, while its caption layout is being refined separately
before sharing. Neither that recording nor these bounded checks establishes
combat, vehicles, dragging, diagonal/multi-z compatibility, input latency, RAM
improvement or general gameplay readiness. The opt-in remains disabled by
default.

Earlier packets remain retained. The initial compile found an if-local variable
used outside its scope and a reserved `run` proc name; both were corrected.
Earlier supervisor output lookups assumed process cwd rather than the DMB file
root; the public runner now puts both in one runtime directory. The first
connected blocked comparison failed because a fractional sleep woke at164.5
before the actual164.85 client deadline. The production admission guard correctly
rejected that input; this was a fixture wait error, not a cooldown regression.
The fixture now loops with positive tick sleeps until the deadline is reached,
without changing the39 assertions or production cooldown arithmetic. Earlier
standalone savefile diagnostics and their unresolved relative-first-read cause
remain documented in the primitive packet.

## Public staging and CI

The public runner stages exact committed Git objects into a fresh directory.
It records every original input hash and both startup adaptations, removes map
includes, and appends the unchanged closed headless probe. It never stages the
private visual wrapper, tokens, accounts, local configuration or saved worlds.
Uncommitted source does not enter the snapshot. On Windows, staging is offline:

```powershell
py -3 tests/human_subtile/run.py --prepare-only --output C:/temp/human-subtile-prepared
py -3 tests/human_subtile/run.py --suite primitive --prepare-only --output C:/temp/subtile-primitive-prepared
```

Native execution through this runner is Linux CI only. The PR step runs the
eleven primitive offline contracts, the human source/runner contracts, both
primitive native profiles and the separate human headless profile. The new
executable tests select both `tests/subtile_movement` and `tests/human_subtile`
through the existing added-test policy. Existing suites remain opt-in. The
minimal world-save stub declares the new loader hook but rejects owned capsules;
only the full-source human fixture implements physical offset restoration.

```bash
python3 tests/human_subtile/run.py --suite primitive --byond-bin "$PWD/BYOND/byond/bin" --output /tmp/subtile-primitive
python3 tests/human_subtile/run.py --suite primitive --control cosmetic --byond-bin "$PWD/BYOND/byond/bin" --output /tmp/subtile-cosmetic
python3 tests/human_subtile/run.py --suite human --byond-bin "$PWD/BYOND/byond/bin" --output /tmp/human-subtile
```

After compilation, the runner copies the DMB and any RSC into one explicit
`runtime/` directory and runs the daemon there. All marker, save and receipt
checks use that binary directory, because native BYOND file IO can be rooted
beside the DMB even when the process has a different working directory. The
human runtime receives the same staged public config; the primitive is
resource-free and does not require an RSC.

Each invocation has at most one active native phase, with a180-second compiler
deadline and120-second daemon deadline. Linux process-group cleanup targets
only that invocation and also runs after normal exit. Phase output is sampled
against a4MiB limit, including nested `data/logs/runtime/*.txt`; runtime logs,
exact LF markers, one unique clean pinned compiler banner/result, engine/build, source
head and assertion/observation receipts are checked strictly. The primitive
cosmetic profile must fail precisely at `physical_east_four_pixels`; unrelated
failures do not qualify as a successful control. Evidence upload retains hashes,
logs and receipts, excluding the large staged resource tree.

The daemon initially binds loopback127.0.0.1:59474 and the fixture then closes
the port. The closed marker is an application witness, not OS socket isolation.
This Linux runner provides process-group cleanup and bounded phase deadlines;
it does not claim the Windows Job resource limits, process census or socket
sampling supplied by root's separate local envelope. It does not exercise a
real connected client or capture video.
