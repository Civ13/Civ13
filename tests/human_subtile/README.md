# Human sub-tile movement: diagonal/default candidate

The current candidate extends the adapter to all eight directions. This remains
fixed-tile-intent movement: key release prevents later queued intents but does
not cancel the current admitted intent. It is not free pixel locomotion or a
new key-up stopping scheme. Every
admitted 32px intent uses at most sixteen native 2px pulses on the same absolute
cooldown interval. Diagonal pulses advance both axes together through the native
offset seam, bypassing the legacy immediate cardinal decomposition only for an
authenticated one-use pulse. The existing ordinal cooldown multiplier is retained.
Collision, partial slide, cancellation, costs and once-only completion semantics
remain physical. The 32x32 footprint and global simulation rate are unchanged.

Ordinary eligible human input initializes the default through
`set_human_subtile(TRUE)` after placement/construction/load. The stored enable
flag remains false until that safe admission. Explicit `set_human_subtile(FALSE)`
(also exposed as IC > Toggle Smooth Movement) at alignment clears pending initialization and preserves legacy movement for the
body's runtime lifetime. Disabling at an owned offset still refuses without
snapping. An interrupted intent now stops each moving axis at its next native
grid alignment instead of preserving the offset indefinitely. Reverse movement
can realign a 2px interruption with a 2px collision-checked move, while consuming
the usual full admission cost/cooldown. The existing paid prone/scramble paths can realign an owned offset after their
normal wait, without forcing an injured player to stand. Pulling and restraints
retain their normal restrictions; stop pulling or release cuffs through ordinary
controls, then reverse or move to the next alignment. A blocked reverse can align in the other direction.
No admin placement participates in the recovery regression. Owned save capsules can initialize on the first eligible input;
arbitrary raw legacy offsets are never silently adopted. Runtime choices are not
saved as account preferences. New/revived eligible bodies initialize on input.

Native interpolation uses the actual admitted distance/time to set `glide_size`,
including Euclidean diagonal scaling unless `LONG_GLIDE` already applies. The
owning client's frame rate is raised to at least 60 and above server FPS while
this mode owns its visual settings. Prior client FPS, camera glide and body glide
are restored only while still owned; intervening preference changes are retained. Settings are restored on opt-out, restricted input, logout, death or body handoff. No
`pixel_x/y` offsets, simulated screenshots or global FPS changes are involved.
The installed official BYOND reference's [gliding documentation](https://www.byond.com/docs/ref/#/{notes}/gliding)
explains that legacy pixel movement interpolates only when client FPS exceeds
server FPS. This motivates the policy; it is not client-rendering acceptance.

The maximum native movement-call budget doubles from 8 to 16 per admitted input,
while admission costs and completion hooks remain once per input. At interval
`D` deciseconds the call budget is `160/D` per second per continuously moving
actor, versus `80/D` before. At D=4 this is 40 versus 20 calls/s. Client rendering
at 60 versus 20 FPS can render three times as many frames. Several physical
pulses can still coalesce in a server frame; 16 calls do not imply 16 network
packets or visible frames. Actual CPU, bandwidth and multiplayer latency need
measurement. Tick-boundary normalization is checked as a 2px physical delta;
DreamSeeker camera/sprite continuity remains a separate visual gate.

Use the current runner for this candidate:

```powershell
py -3 tests/human_subtile/run-diagonal.py --output <fresh-evidence-directory> --byond-bin <516.1688-bin>
```

`--prepare-only` stages exact committed Git sources. `--compile-only` compiles
without starting a daemon. The current fixtures and strict receipt oracles target 1688 and run the 42 existing human
assertions plus 117 diagonal/default/interpolation/recovery assertions, and separately
the 52 existing mining assertions. These are expected counts until a complete
native receipt confirms them. `--control legacy-split` and
`--control cardinal-arithmetic` must each reach exactly
`diagonal_32px_per_axis` after four new assertions. The offset-recovery control must fail exactly
`cancel_stop_reverse_realigns_without_snap` at new assertion 86. Complete failures
are retained. The optional `human_subtile_fixture_client_visuals(C)` entry tests
actual body handoff and intervening client/body preference changes; it requires
a separately authorized real client and is not called by headless CI.

Windows uses the unchanged `scripts/native_fixture.py` Session and byte-identical
copies of its frozen launch/accounting helpers, with a separate observed 1688
binary-hash allowlist. One process per Job, memory/CPU/time/output limits,
retained cleanup and the no-sampled-sockets policy remain intact. The 1681 hash
refusal and the later 1688 startup-loopback socket rejection are preserved; the
latter prevents local Windows runtime acceptance; see [the bounded runtime proposal](RUNTIME-ISOLATION.md). No connected-client input or capture has
been performed for this candidate. Before default-on deployment, acceptance
still needs permitted native fixture completion, actual client admission/cost
parity and genuine DreamSeeker observation at cardinal/diagonal transitions,
tile boundaries, corners, stop/reverse and walk/run speeds. A rebuilt world and
coordinated server restart are required after merge.

## Historical cardinal prototype and evidence

The following records the older 4px/1681 prototype. Its assertion counts and
connected-client results do not validate the current candidate. Historical source/oracles remain in Git at `bef0ba6534d56ca6395057fd8508d037afeedec0`; current runners and fixtures now target 1688.

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

## Combined bump-mining integration (#3231)

The new `--suite mining` profile compiles the complete merged game and runs
`human_subtile_fixture_mining()` in the same closed headless envelope. Its
52 assertions compare ordinary tile movement with enabled movement at physical
Y offsets 0, 4 and 28. All tested bumps originate in native movement through the
production turf Enter/Bump path; the probe never directly invokes Bump or mining
admission. It checks exact mining origin/offset snapshots, blocked movement
context release, repeated collision reservation identity, a real production
`do_after` completion, physical orthogonal movement cancellation and release of
actor, wall, tool, origin and progressbar references. The fixture uses a pickaxe
with usespeed 4 to bound runtime and counts final ore/collapse effects instead
of changing the terrain or producing ore. It does not establish mining yields.

The `mining-position` control removes only the production action's step_x/step_y
validity guard in the staged copy. The ordinary tile case still cancels on loc
change; the first enabled same-anchor 4px drift must fail exactly at
`mining_drift_rejected` (assertion 24). A different failure is rejected.

```bash
python3 -B tests/human_subtile/run.py --suite mining --byond-bin "$PWD/BYOND/byond/bin" --output /tmp/subtile-mining
python3 -B tests/human_subtile/run.py --suite mining --control mining-position --byond-bin "$PWD/BYOND/byond/bin" --output /tmp/subtile-mining-control
```

These profiles are wired into the existing new-suite CI job. At introduction,
45 offline contracts passed (26 human, 8 bump-mining, 11 primitive); native
compilation/execution of this new combined profile still requires CI. The older
42 headless / 39 connected-client results above do not cover this addition.

Headless mining authority is explicitly adapted, just like headless movement
authority. It cannot prove native client ownership. The optional
`human_subtile_fixture_mining(C)` entry requires a real attached fixture client,
uses production `client.Move`, preserves both production authority checks,
observes `client.moving` inside the real Bump and asserts it is released on
return. It has 57 assertions (one initial client check plus 14 per case).
It is not invoked by the closed CI runner and remains unaccepted until a
separate authorized connected-client session executes it. Its drift leg is a
full admitted movement; the headless leg separately tests one-pulse same-anchor
4px drift. Neither entry proves keyboard delivery, rendering, latency or broad
movement/combat compatibility. The production opt-in stays disabled.
