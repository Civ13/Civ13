# Bounded wildlife native validation plan (authorized, review pending)

The user approved isolated cloud compilation and bounded movement/save tests as
reviewed stages become ready, and approved the specific restricted temporary
Docker setup on the GitHub-hosted runner. Main must first review the repairs to the e10e9cbf
findings and the exact frozen source, fixtures and execution envelope. Bind
receipts to that clean Git commit, fixture source hashes, compiler and daemon
hashes, and fresh disposable output locations. The prior rejected Windows daemon
attempt in `RUNTIME-ISOLATION.md` remains rejected; do not retry it, relax its
socket policy, or execute native tools on the user's desktop. No test has run.

## Toolchain and isolation

Use the repository-pinned Linux BYOND 516.1688 archive, 4,887,281 bytes, SHA-256
`16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9`,
validated by the repository's `scripts/byond_toolchain.py` and
`scripts/byond_runtime.py`; record compiler/daemon hashes and banners. This is an
observed exact-byte pin, not a vendor-authenticated signature. BYOND alone is in
scope; OpenDream behavior is not a BYOND timing oracle. Do not change production world FPS, server security, configuration, Gaia or an
existing checkout. Only the isolated fixture may vary `world.tick_lag`.

Proposed maximum resource envelope: a fresh ephemeral 2-vCPU, 3-GiB-RAM worker,
1 GiB temporary output/disk, 64 processes, and 10 minutes wall time total; one
compiler at a time (120 seconds maximum), then at most two sequential daemons
(90 seconds each maximum), with process-tree termination and retained timeout
receipts. These are proposed caps, not claims that a run will fit; a resource
failure is a failure, not grounds to increase limits or retry without approval.
No egress during compilation or execution, no external listener, no credentials
inside the test worker, and no clients, maps or saves from a real deployment.
Acquire the pinned archive and reviewed source before the sealed test starts;
verify their hashes and disable network access. Temporary cloud-test publication
is permitted only if needed for this validation and must not expose credentials
or be represented as a ready or merged feature. Enforce a closed network namespace; record any loopback
listener at startup, fixture port closure and eventual no-listener state. Do not
claim a fully socket-free engine if startup opens loopback. No external connection
is allowed. Save fixtures write only under the ephemeral evidence directory.

## Compile and bounded regression scope

1. Compile an isolated full-source-derived NPC fixture with the pinned compiler.
   Record exit code, warnings, compiler version, source/DME/output hashes and logs.
   Its startup is isolated and map includes are removed, so this is not a full
   production-game compile. A full exact-commit game compile requires a separate
   reviewed cloud step; neither compile modifies the production DMB.
2. Future broader fixtures should run at `world.tick_lag` 0.5, 1 and 2 against
   native walking controls: follow and pet `walk_to` around blockers and at cutoffs;
   scared/pet `walk_away`; fly/mosquito/bat random/towards/flee and curtain
   redirects; Boreas/Echofiend path targets and stops; cat/dog and insect contact;
   preemption, blocked alignment, changed semantic target with lost readiness,
   control/riding transitions and pursuit arrival. Count native physical moves,
   callbacks, paid intervals, Life ticks, RNG decisions and eligible bites.
   Include both successful and blocked cases, and a sustained contact scenario
   that would expose starvation. Verify no extra roll or deferred attack.
3. Future broader temporary-save fixtures should cover aligned and owned partial positions,
   interrupted movement and following links. Compare baseline and candidate state,
   confirm workers/capabilities are excluded, and reject corrupt capsules without
   mutation. Capture LOS refresh and movement ownership around each save/restore.
4. Collect machine-readable per-case pass/fail, exact commit, fixture identity,
   hashes, timeouts, resource use and process/listener cleanup. A compile pass or
   source-level model does not establish native collision, timing, visual motion,
   save or gameplay correctness. Real-client visual tests require separate scope.

## Proposed harness and fixture boundary

`tests/human_subtile/cloud_npc_smoke.py` is a **draft for main review**, not a
runtime result or an authorization to launch immediately. It reuses the existing
`run-npc.py` staging, pinned-runtime verifier, process-group runner, compile
validator and vendor receipt oracle. One compiled isolated DMB runs two sequential
90-second daemons in distinct fresh runtime directories:

- The unchanged vendor fixture requires its exact 46 assertions, all eight
  physical pulse traces, and the owned-partial graph-codec round trip. It does
  not exercise the new wildlife owner or contact behavior.
- `cloud_wildlife.dm` has nine separate assertions for a 32x32 test-only mosquito
  subtype: initial admission, contact rejection during a pulse, a held settled
  observation window, explicit observation and resume, and no stale replay after
  simultaneous semantic and readiness changes. Its contact tick is invoked directly;
  it does not test Life cadence, actual bites, disease, RNG, multi-tile geometry,
  continuous contention or real-client motion. It uses no fake client. The two
  receipt validators reject mixed suites, missing checks, wrong source or engine.

The harness pins the archive and all four executable/library members using
`scripts/byond_runtime.py`, requires a clean exact Git HEAD, records source and
artifact hashes, and rechecks the pinned files before each native phase. It clears
its own environment before starting children. The cloud provider must start the
worker with no credentials in the first place. The program checks non-root/no
capabilities/no-new-privileges, read-only source and toolchain mounts, only the
loopback interface, an externally preconfigured dedicated cgroup with no writable
membership and only the supervisor present, finite CPU/memory/process limits, and
a fresh dedicated filesystem of at most 1 GiB. It never configures those controls.
Existing process-group cleanup runs in a finally block; any remaining cgroup member
is a failure requiring the provider to destroy the whole worker. The harness
writes bounded phase/failure status when Python is alive and offers a 15-second
evidence lease; the source-stage task-specific controller is intended to capture OOM/SIGKILL/host-timeout
state and remove the exact owned container before its 600-second deadline. Its
Docker adapter and independent watchdog remain unreviewed and unexecuted. A 600-second
supervisor alarm bounds staging and both daemons as well as the 120-second compile
and 90-second daemon deadlines.

**Outstanding security-sensitive provisioning for main review:** arrange a fresh,
unprivileged cloud worker with the sealed network namespace (loopback only, no
host Unix-socket mounts, no egress), dedicated read-only/non-delegated cgroup with
3-GiB memory / 64-PID / 2-CPU caps, no-new-privileges and no capabilities, read-only
source and exact pinned toolchain, and a fresh dedicated <=1-GiB scratch filesystem.
Ensure the cloud supervisor destroys the worker and its process tree even if the
Python supervisor crashes or detects an escaped child. These are cloud-provider
settings; the harness does not change host security or network configuration. A
loopback-only interface check cannot prove absence of shared host sockets or all
namespace escape paths, so independently review those provider guarantees before
passing `--reviewed-cloud-envelope`. If the provider cannot supply and attest that
envelope, stop before launching a compiler or daemon.

After approval of the exact commit and envelope, the intended invocation inside
the already provisioned cloud worker is:

```text
<verified-python> -B tests/human_subtile/cloud_npc_smoke.py
  --head <reviewed-40-hex-commit> --byond-bin <read-only-pinned-bin>
  --byond-archive <read-only-pinned-zip> --scratch-root <fresh-dedicated-mount>
  --reviewed-cloud-envelope
```

`run-npc.py --prepare-only` still stages exact Git objects without native
execution and `--compile-only` retains its prior scope. The existing Linux
`run.py` runtime executes human, primitive and mining fixtures; it does not by
itself launch this NPC fixture or enforce the cloud envelope. A broader wildlife
movement/save suite still requires additional reviewed native fixture code and
receipt assertions. No suite has been compiled or run in this stage, and the
user's test authorization does not authorize deployment, merge, or a ready-feature
claim.

The source-stage worker includes a bounded in-container i386 loader trace for Git,
Python and four pinned BYOND ELF members. It records resolved library paths and
hashes and rejects missing libraries. It does not prove optional dynamically
loaded dependencies, image provenance or runtime compatibility; those need the
separate exact-image review. No loader trace has been run.
