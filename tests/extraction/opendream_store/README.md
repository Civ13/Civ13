# Extraction store OpenDream registered-workflow route v4

Source-only successor against exact game/workflow parent f5620b232b4fa159930b3b393c9794c05d4fb7b1. Default OFF, unallocated and unpublished. Frozen V4 remains unchanged and on whole-packet HOLD for its command stdout shadowing bug. Registered-route-v1 and V2 are also preserved unchanged. V2 is on HOLD for final receipt deadline acceptance and compile output accounting defects.
The 87 offline tests inject process, kernel, network and filesystem effects where
those operations are under test. They establish source contracts, not successful
OpenDream compilation, package viability, native cleanup or game acceptance.

## Proposed execution

The manual entry accepts a canonical JSON route policy plus its SHA-256. Enablement
also requires a named owner, allocation, expiry, independent executor/monitor review
digests, exact six-file driver closure, startup/profile pins and resource envelope.
`route.example.json` deliberately cannot authorize execution. The pre-dispatch
policy uses `run_id=bind-current-run` and `run_attempt=1`; entry derives and records
the actual GitHub run identity once. Platform reruns are rejected.

One root deadline starts before admission reads: at most 2,190 seconds, including
30 seconds reserved for cleanup. Setup gets at most 1,500 seconds within that
deadline. The workflow's execution step is 37 minutes and job is 40 minutes.
Every slow effect has fresh deadline/expiry checks. Process creation checks run
inside the launch function after log preparation and directly before Popen init,
then again after creation. Frozen V3 launch code fails the same late-creation
oracle that V4 passes, using injected opens and Popen only.

The owned setup child fetches exact game/engine commits and recursive committed
gitlinks, verifies the Robust commit, exports regular tracked blobs and applies
the engine's committed Robust authentication transformation. Source receipts retain
original/effective manifests and the patch digest. It retrieves exactly Microsoft
SDK 10.0.401 linux-x64 and checks the official SHA-512 before bounded regular-file
extraction. No SDK or source download has occurred during preparation of this packet.

The parent monitors setup, restore, build, package and publish through the same
owned-session backend. The actual SDK version must be 10.0.401. A single build's
complete compiler/server output closure is measured, copied and sealed once into
a deterministic JSON container. Actual dependency-resolution files and command
receipts are retained. Output hashes are measured after that build; no predictive
output hashes or second rebuild can substitute for those bytes. Setup/install then
revalidates that exact sealed package before the five existing extraction store
cases and their unchanged roots/nodes causal oracles.

Allocation, source/SDK, build and package receipts form a predecessor-hash chain.
The retained container is independently hashed before orchestration. Failure keeps
the primary diagnosis and bounded cleanup evidence. Cleanup retains the reviewed
per-member pidfd identity policy, attempts later members after individual failures,
and rejects surviving owned processes. There is no numeric-PID signal fallback.

The user explicitly overrode unreliable available-memory admission. CPU admission
and sampled RSS/disk/time stop limits remain. Sampled monitoring is not hard
containment, cannot contain session escapes and has not been exercised natively.
The inherited derived-admission schema uses a placeholder memory capacity value;
it is not measured capacity evidence. Real setup/build size and duration may exceed
the conservative caps. Failures must be retained rather than weakening limits.
Child command output is bounded on receipt, but communicate can temporarily buffer
more before that check; sampled RSS is the remaining observation boundary.

## Registered workflow route and CI consequences

This successor changes the already registered `.github/workflows/test.yml` at the
exact f562 parent in a task-local patch. It does not publish or dispatch anything.
The old new-workflow alternative remains frozen and unpublished in V4. This patch
contains no `.github/workflows/extraction-store-opendream.yml` addition.

GitHub supports selecting the branch/ref of an existing registered workflow.
The official CLI resolves that workflow's ID, optionally reads its input schema
at the selected ref, and sends `ref` plus `inputs` to that ID's dispatch endpoint.
That supports preparing this alternative; it is not proof the platform has accepted
our new inputs. Any API validation denial is a stop/report condition. No retry
through an alternate route or vendor bootstrap bypass is authorized.

Four new default-disabled inputs are `opendream_store_only`,
`opendream_store_policy_json`, `opendream_store_policy_sha256` and
`opendream_store_selected_sha`. The selected SHA must match the exact dispatch ref
commit. All eleven preexisting native opt-ins must be strictly false. A new
one-minute admission job, without checkout or external acquisition, validates these
conditions, repository, first attempt, policy allocation/run binding and digest.
Only successful admission publishes `only=true`. The actual entry then performs
its full existing route/expiry/driver admission again before native effects.

Only explicit manual OpenDream-only selection plus that admission result suppresses
the ordinary build job. On PR, push, default/manual and other native selections,
the old build predicate retains its behavior. Mixed opt-ins fail admission before
change selection or any native acquisition. The always-run build job may report the
failed/skipped selection via its existing first validation step, but cannot acquire
BYOND: its existing `game == true` setup gate has no successful selection output.
Extraction-instances and every existing build step are byte-identical to the exact
parent. Evidence-checker adds only the conditional timeout described below. The
selector remains unchanged; the reusable workflow adds only a numeric timeout input
and its job timeout, with the original 360-minute default retained.

A new two-minute secret-free offline job runs the complete 80 injected contracts
on every automatic PR/push and admitted manual OpenDream run, including nonordinary
helper PRs where the parent selector emits no introduced suites. Its explicit
always/not-cancelled predicate permits automatic events despite the skipped manual
admission dependency. It uses pinned checkout with credentials disabled, and one
pure unittest invocation without vendor, compiler or game acquisition. Failed or
skipped offline checks block recovery.

The new recovery job requires successful admission, change selection (including
normal source actionlint) AND the offline job, has a 40-minute job/37-minute executor
step and pinned
checkout/upload actions. It reuses the unchanged V4 launch/monitor/cleanup/oracle
contracts. It has no automatic PR/push activation. The resource/deadline policy
still permits only one build and one five-case run after separately accepted source,
CI and durable allocation review. This packet performs no such execution.

Job time bounds are separate: admission 1 minute, offline contracts 2 minutes,
change selection 3 minutes and evidence-checker 3 minutes on explicit manual
OpenDream selection, recovery 40 minutes. The reusable change-selection timeout is a
numeric workflow_call input defaulting to 360; the caller supplies 3 only for manual
OpenDream and 360 otherwise. Evidence-checker uses the same conditional 3/360 rule.
Other callers and normal PR/push/default/native routes preserve their former default
timeout. These are job limits, not a 40-minute whole-workflow promise. Queue and
preflight time consume the frozen policy's absolute UTC expiry; no deadline is
extended when execution finally starts. If admission/preflight exhausts validity,
the actual entry rejects the expired policy before native work.

The full parent workflow/reusable fixtures are pinned by SHA256. Tests verify the complete
old job bodies, inputs/defaults and all 163 parent predicates, evaluate them across
48 event/resource/cancellation contexts, execute the actual admission script for
all 2,048 native-opt-in combinations, and cover changed head/policy/repository/rerun rejection. Added tests exercise
automatic events with skipped admission, manual failure/success, cancellation,
offline failure blocking recovery, both timeout expressions and full reusable
parent projection with only the declared input/timeout changes removed. Exact-parent selector tests cover nonordinary helper push/PR, explicit
build: requests, master events and manual selection with injected changed paths.
An ordinary master-target PR still selects BYOND compilation/extraction tests;
this has not been weakened. A nonordinary helper branch/PR without build: retains
the parent's no-game behavior. Root owns final complete three-dot/all-workflow
review before any publication.

The prepare.py fix separates `stdout_bytes` from `receipt_file`. New tests execute
actual main/cmd/receipt writes with injected paths/process output/fsync, stop only
after first exact Git HEAD parsing succeeds, and show frozen V4 fails the same
oracle. This is narrow regression evidence, not a complete acquisition/build test.

Local exclusive claims and workflow concurrency protect job-local reuse and serialize
runs; they do not prove durable allocation uniqueness across independent runners.
The allocator must durably reserve the allocation before one authorized dispatch.
No duplicate dispatch is authorized by possession of this packet.

Official references:

- [Manual workflow registration and ref selection](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
- [Microsoft .NET 10 release metadata](https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json)
- [Official CLI workflow dispatch implementation](https://raw.githubusercontent.com/cli/cli/trunk/pkg/cmd/workflow/run/run.go)
- [GitHub-hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

## Finalization and output-envelope corrections

The final bootstrap receipt is checked against both the original root monotonic
end and the frozen policy UTC expiry immediately before and after its actual claim
write. A slow write that crosses either clock rejects the run. Its immutable
success-path bytes say `PENDING_FINAL_CHECK`, never PASS: bytes written before a
post-write check cannot assert that later check passed. Acceptance requires the
successful post-write check and a successful executor return. Case/orchestrator
PASS receipts alone do not establish complete hosted finalization. Failed or late
retention preserves the raised diagnosis; there is no rewrite/retry to create a
new success receipt after expiry.

Compile and runtime both report bytes/files/depth from their active `cases/<case>/`
subtree to the existing 128 MiB case guard. Retained SDK/source/build/package and
other cases do not consume that case's output budget. The entire owned workspace
still has the unchanged setup envelope of 8 GiB, 10,000 files and depth 16 in every
phase; RSS/socket/ownership checks and case/command log limits remain in force.
Thus excluding retained archives from the case guard does not remove the overall
workspace stop. Frozen V2 actual execute/observe methods are inert causal controls:
old finalization accepts late writes, and old compile accounting rejects a legal
200 MiB retained archive before runtime. The same injected oracles reject late
writes and permit all five small cases with the fixed actual methods. Oversized
active-case and entire-workspace negative controls still reject.

## Registered-route-v4 package correction and remaining holds

This intermediate source-only successor preserves the complete, unchanged
`out-server/OpenDreamServer_linux-x64` tree under `package/server` and the full
`out-compiler` publish under `package/compiler`. It launches
`dotnet package/server/Robust.Server.dll` with cwd `package/server`; absolute
case-local configuration/data/JSON arguments remain unchanged. It never adds the
three `bin/Content.Server/OpenDreamServer` wrapper files. The server's Resources
and Assemblies remain in the RID layout. Compiler deps/runtimeconfig/dependencies
and DMStandard are retained; all pinned DMStandard sources must be present with
matching source hashes. The scoped store profile disables native identity, so
absence of the optional native BYOND identity bridge is not a blanket gate.

Before reading completed output bytes or allocating hex strings, the runner
measures both output trees and computes exact canonical JSON overhead plus twice
the raw byte total. The existing 128 MiB container cap is unchanged. Each read
must match its measured size, and final serialization must match the prediction.
Oversize rejects before any fixture compiler or server launch. Injected tests
cover missing metadata/standard files, complete extra dependency/resource
retention, stale standard bytes, oversized measurement without output reads,
post-measurement growth, and an exact JSON boundary including Unicode paths.

Engine-owner assessment binds source layout and recipe evidence, not actual RID
artifacts. Its digest is recorded in `package-assessment-receipt.json`. The reported
331,740,529-byte source-layout inventory is not an exact RID measurement. Actual
RID/compiler output fit remains unknown and may reject without changing caps.

Dependency provenance is explicitly first-resolution scope. The pinned repositories
have no committed NuGet lockfiles, so top-level `--locked-mode` does not establish
a frozen nested FullRelease/RID graph. The receipt records every observed
project.assets identity, configured public feeds, package versions/paths/content
hash claims, complete target-graph digest and original asset-file hash. Compiler,
content server, Robust server and package tool project receipts are required.
Malformed graphs, missing package content identities or unsupported feeds reject.
Generated resolution artifacts remain separate from authenticated Git/Robust
transform identity. The resulting complete compiler/runtime output is measured
and sealed once, before all fixture launches, with no later restore or rebuild.
This establishes exact tested package bytes; deterministic transitive dependency
reproduction is not claimed. Stronger generated-lock enforcement is optional
future work, not a prerequisite invented for this first-resolution build.

This packet still requires independent source review, root integration/exact-head
CI, durable allocation and bounded runtime evidence. No restore, acquisition,
build, dispatch or native test was performed.

The accepted V3 finalization checks, active-case/global accounting, pidfd cleanup,
launch guards, five-case oracles and manual workflow route remain intact.

## Offline review

Use Python 3.11+ from this directory:

```
<verified-python> -B -m unittest -v test_run test_backend test_signals test_hosted test_preparation_receipts test_workflow_route
```

Some mocked entry tests print a simulated PASS line. Only the unittest verdict is
the offline result; that line is not a real compiler/server receipt. Actionlint 1.7.12 passed both full proposed workflows with `-shellcheck= -pyflakes=`.
No hosted CI job, SDK download, build, process/socket experiment or native BYOND test ran. Review packet hashes bind the source, tests, log and proposed patch.
V1/V2/V3/V4 and the earlier Ubuntu route remain immutable historical packets.
