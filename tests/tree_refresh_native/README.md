# Current-source native tree callback and refresh measurement harness

This separate harness implements the plan in docs/tree-refresh-measurement.md. It is
prepared for independent review. No compiler, daemon, client, workflow execution, pixel
acceptance or performance measurement has been run for it. The frozen
tests/root_tree_presentation native fixture remains unchanged.

The manual workflow is .github/workflows/tree-refresh-native.yml. It has no push, PR,
schedule or automatic native consumer. Ordinary CI runs only the registered offline
preparation/protocol tests. Default workflow mode is prepare: download the exact pinned
Windows installer as data, verify its size/SHA256, extract it with hosted 7-Zip without
installation, and stage exact committed source. This is not permission to dispatch
either mode before Main review.

## Actual engine boundaries

The new DME contains the complete current game sources and assets, excluding maps. It
reuses the existing two startup-isolation adaptations and only the previous
initialization helper body. It replaces fixture client creation, Topic and disconnect
boundaries, provides a tiny fixture HUD using actual production plane-master types, and
suppresses world Export/Import/Reboot/Topic. It never loads player preferences,
accounts, production data, admin control or saves. The world is 64 x 64 x 1, with a 15 x
15 view, 20 FPS and zero camera pan. Connections are guest-only and use loopback. The
fixture resets rand_seed to 13,013 before actors/trees and records actual map, view,
FPS, tick_lag and icon_size and both engine builds, together with host OS/CPU and
sampled process resources. Inputs seed the four photometric corners; update_overlay, the
mask snapshot, RGB/icon operations, LOS capture and geometric decisions are real
production DM. This does not exercise natural lamp propagation or the lighting process
queue.

Instrumentation is added only to the staged copies, with before/after hashes. The real
human SelfMove uses the actual production client/body authority check with the fixture
input controller setting moving/canmove, actual smooth pulses, generic Move, the
engine's native parent Move, actual observation Entered, pre/post invalidation,
reconciliation, geometry capture, root scene admission, root and fallback presenters,
native images/icons and committed lighting. Native parent-return rows retain result,
coordinates, step offsets, time and phase count and the first pulse's real image state.
Offset callbacks are observed, not assumed identical to the modeled offset adapter.
Entered and post-move witnesses retain native refs, client image membership, icon
presence, published frame identity, plane/override/mouse flags and actual affected-
context refs. Up to 64 actual witnessed image/icon objects are retained only through the
event to prevent native ref recycling from masquerading as stable identity; they are
never re-added to client.images. This bounded observational retention affects GC timing
and is disclosed in cost/RSS interpretation.

These are server-side engine and render-state observations, not client pixels, packet
delivery, native mouse dispatch or flicker acceptance. Genuine video on a fresh isolated
real client is still needed to judge continuous canopies, root-source lighting,
shadows/weather overlap, movement timing and popup/hover. No current Gaia or existing
user session may be touched. The runner refuses a self-hosted/desktop environment; fresh
GitHub-hosted Windows manual attempt 1 is required. Fresh private profiles are used for
daemon and DreamSeeker processes; non-Guest clients are rejected. Launch/guest/DirectX
availability on that runner is unverified and must fail with retained evidence rather
than using another user's client, authenticated session or a permissive fallback.

## Fixed workload and resource contract

There are eight cases: one or two connected clients, 64 or 256 discovered roots per
disjoint neighborhood, and root composition or intentional native fallback. One client
is launched initially; the second is launched only after all four one-viewer cases. At
most 512 roots exist. A real low-alpha foreground world object deliberately induces the
known fallback reason. Budget fallback fails the intended root case; no renderer audit
limit is raised.

Each case runs five warm-up and 20 recorded events for each of four classes: audit,
smooth viewer tile move, opaque object Move, and queued committed-light batch of at most
64 roots. This produces 800 events in total, including 640 recorded events. The two-
viewer opaque control marks the remote viewer dirty but requires zero synchronous
captures; a real production visibility process pass is recorded separately. Its actual
fixture priority allowance and last, highest and last 20 scheduler durations are saved.
This fixture contains only the visibility process, so its allowance is not the full
production scheduler mix. Instrumentation adds bounded overhead; metrics must not be
presented as uninstrumented production timing or a speedup.

| Resource | Limit |
| --- | --- |
| Compiler | 120 seconds, plus 30 seconds for cleanup |
| Native world and clients | 180 seconds, including connection waits, plus 30 seconds for cleanup |
| Controller | 360-second work deadline; authorization check reserves 390 seconds |
| Owned processes | One daemon and at most two clients in one retained-handle Job |
| Owned memory | 1,920 MiB aggregate private-memory hard ceiling and sampled RSS ceiling |
| Watcher | 128 MiB private memory; 6 GiB host free-memory floor |
| Generated evidence | 16 MiB total; native event input capped at 12 MiB |
| Supervisor stream | 4 MiB, at most 1,900 rows and 32 KiB per row |
| Per event | 64 spans, 16 callback phases, and 32 native returns or affected-context samples |
| Independent runs | At most three, one per invocation, with no automatic retries |

The free-memory floor may block a hosted VM; do not relax it without review. Membership
and cumulative process counts reject unexpected children. Main must enforce the cross-
dispatch run ledger: run_index alone is not a global counter. The current user window
ends at 2026-11-02T13:23:00Z, as enforced by request.json.

During measurement, each resource poll appends one bounded JSONL row. It never rewrites
the sample history or the growing execution receipt. Launch identities are appended
once. The small execution summary is written at launch/client milestones and after
cleanup; it holds a stream reference, row count, first/last observations and peak RSS.
Rejected observations are appended before raising. This removes quadratic receipt I/O,
while constant sampling and fixture instrumentation still contribute overhead. Compiler
containment receipts are written outside the native measurement phase.

Only this fixture's IPv4 loopback port 59479 is admitted by sampled socket inventory. No
firewall, credential or global security setting changes occur. This sampled oracle does
not prove continuous absence of transient connections. No external hooks are enabled.
Owned Job kill-on-close and retained exit waits provide cleanup, and failures retain
original cause, native rows, compiler logs, resource/socket observations and secondary
cleanup/retention errors. No cleanup removes source/artifacts or unrelated processes.

## Review and later execution

1. Review the source/runner/workflow, including native launch and cleanup.
2. If Main authorizes preparation, dispatch manual prepare on one full source
   SHA. Inspect the exact staged instrumented source and installer/bin manifest;
   retain the emitted manifest SHA256. No engine runs in prepare mode.
3. Only after independent acceptance, dispatch execute at the same immutable
   source/workflow SHA with that exact manifest hash, an approved run_index and
   a deadline within the current window. Regenerated manifest must match. A
   source/toolchain/input mismatch, missing ceiling, expiry or other failure
   stops; no alternate route or silent retry.
4. Preserve all failures. Native compilation and first execution remain pending.
   A source-only green PR cannot upgrade them to native acceptance.

Preparation CLI (source must be committed and clean):

    py -3 -B tests/tree_refresh_native/prepare.py --source-commit FULL_SHA --output NEW_PRIVATE_PATH

Offline contracts:

    py -3 -B tests/tree_refresh_native/test_harness.py -v

The receipt oracle requires complete 800-event case identities, actual native fractional
parent returns, Entered withdrawal, root identity retention/fallback identity
replacement, unrelated-viewer isolation, hidden hover/examine denials, owned denial
masks, mutation-induced capture failure, and matching pending-light identity retention.
It measures actual TICK_USAGE endpoints and source TICK_DELTA_TO_MS conversion. Cross-
tick/negative deltas are unresolved, never zero. Same-tick whole-tick spans stop and
retain the failed event. Summaries use only 20 recorded events per case/class; per-
client reconcile p95 is compared to its actual recorded allowance. Unresolved timers or
over-budget samples prevent cost acceptance. Smooth multi-tick whole-event timers will
remain unresolved; per-capture/reconcile values remain individually useful, with that
limitation. No result proves long-running stability, pixel delivery or acceptable dense
live server scaling.

An execution with valid native dispatch but unresolved/over-budget cost is marked
measurement_incomplete and exits nonzero after owned cleanup. It is not reported as an
overall native measurement pass. Raw per-capture/reconcile timings remain available for
review. The derived retained launcher is the committed current-pin implementation with
only its binary-allowlist import replaced; its suspended assignment, stripped private
environment and handle/Job creation remain intact and are separately reviewable.

Synchronous and scheduled per-client spans/counters are retained separately, including
the remote viewer capture count and unfinished process snapshot. Identity details are
bounded to the first two roots per client; admission/owned-image and allocation counters
cover the full discovered scene. This controls evidence size and is not an assertion
about every canopy pixel.

## Bounded notification and failure evidence

Light notifications use a separate constant-size aggregate. There are at most
128 calls per batch: one explicit pending notification and at most one committed
overlay callback for each of 64 roots. The producer-source contract verifies the
single overlay notification site. Counts, resolved/unresolved totals, sum and
maximum time, and first/last native endpoints are retained. These calls do not
consume the 64 ordinary span slots. Overflow still fails closed and has an
offline negative control; no unchecked timing-cap increase is used.

Every caught native failure saves the active outer event before clearing it,
including errors during scheduled work or pre-event identity collection. The
failure includes the cause, last clock and identity-lease count. A 128 KiB
serialized-row ceiling falls back to an explicitly truncated diagnostic envelope
with counts, original length and a correlation MD5. The first failure is retained;
secondary row-write/cleanup errors do not replace its cause.

A live metadata census covers generated files in the staged world, owned output
and extracted binary directories, including root logself files, nested runtime
logs and unexpected diagnostic paths. Immutable input sizes are checked. Scans
run at most twice a second and read metadata only, with an 8,192-entry,
1,024-generated-file and 16-level depth bound. Each scan's duration/counts and
rejected state are appended to a separate stream capped at 1 MiB, 400 rows and
16 KiB per row. This observer overhead is retained and must be considered during
cost review. The check is sampled, not an instantaneous disk quota.

All generated diagnostic/state bytes share the 16 MiB live cap. Only the exact
compiled artifacts and owned-profile BYOND resource caches have a separate
aggregate 1 GiB ceiling. Oversize diagnostics retain bounded prefixes after owned
cleanup, with original sizes and truncation markers; truncation prevents a pass.
The source hashes are rechecked after the native world exits. The Windows daemon
uses the existing -invisible/-close lifecycle flags. None of this has been
executed as native acceptance yet.

After owned cleanup, a fresh forced census discovers late diagnostics before any
retention copy. Copies share the actual remaining 16 MiB state budget, reserving
256 KiB for final receipt/census envelopes. An event stream that cannot fit a
second copy retains at most a 1 MiB marked failure prefix; it cannot pass. Unknown
cleanup logs share the same bound. A final forced census runs after actual copies
and receipt persistence and accounts for its own append. Overflows mark failure;
bounded failure envelopes may exceed an already-breached ceiling to record the
rejection, never to declare acceptance. Local source-only manifests keep a null
toolchain and cannot authorize execution. Data-only hosted preparation and review
of its actual toolchain-bound manifest remain necessary before one native attempt.

## Entered withdrawal diagnostic (source-only, 2026-11-02)

This revision targets the deployed a48c2b226 source. It reuses the separately
accepted explicit-world cleanup correction from the previous failed compiler
attempt. The original failed attempt remains evidence; this revision has not been
compiled or executed. Later Master spelling/job-title concerns remain Main-owned.

Read-only staged observations now bracket the actual native parent Move, Entered,
root/mask invalidation and reconciliation/publication. Entered's old-location and
mover calls are explicitly labelled without changing their arguments, ordering or
return values. The first native call containing Entered is sampled; later native
pulses/Entered calls retain bounded aggregate counts. The existing per-pulse
native-return and before/after two-viewer witnesses remain unchanged.

Only iteration 1 (warm-up) of viewer_move in each of the eight cases receives the
detailed trace. Each trace is capped at 64 rows and 64 KiB; all eight at 512 KiB.
No processes, events, measured samples, timeouts, native input ceiling or 16 MiB
combined evidence allowance are added. The 64 witnessed image/icon lease limit is
unchanged; a sampled denial-mask image is also held through that event to prevent
reference reuse. No held image is re-added to client.images. Detailed tracing ends
before the scheduled pass. Recorded callbacks still have extra branch checks, so
costs remain instrumented observations and never a production performance claim.

Each sample records sequence, native-call ID, world tick and tick-usage clock,
invalidation reason/flags, body/offset and source identity, compositor/fallback
state, sampled image/frame refs and membership. Mask fields are facts: dirty and
mutation flags, published-policy equality, mask counts and a sentinel denial
image. Policy equality is NOT fresh LOS authorization or proof of valid pixels.
The observer never captures new geometry, calls an authorization decision or
changes a mask, image, icon, light or lease admission.

The existing mutation suspension/recovery control is traced after the movement
sample, with the same immediate withdrawal oracle. Its owned mutation ticket
causes reconciliation to return before capture; `mutation_suspended` is emitted
at that actual early return after withdrawal. The protocol requires the active
mutation and owned context between reconcile entry and return, then a closed
ticket and restored publication. The later `capture_unavailable` phase remains
an observation of an attempted capture returning null; it is not a substitute
for this control. Offline phase/ownership/omission controls and a staged-source
branch check guard that distinction; they do not execute native dispatch. Existing opaque mover,
lighting, hidden hover/examine, unrelated-viewer, failure-retention and cleanup
controls remain mandatory. Teleport, eye/body replacement and client pixels are
not newly exercised by this workload; see docs/tree-refresh-measurement.md for
follow-up acceptance. Removing every newly added trace line exactly reconstructs
the previous staged adapters, checked offline without Git-history dependency.

No native attempt, live operation, deployment or production flicker fix is
authorized by these instructions. A fresh source/toolchain-bound manifest and
specific reviewed execution approval are required before any new native attempt.

## Data-only dependency audit

The manual workflow's `dependency-audit` mode is a separate five-minute hosted
Windows job. The native fixture job is excluded for that mode. It acquires only
the pinned official installer as data, rejects non-HTTPS/off-domain redirects,
and reuses the existing bounded extraction without running the installer.
It never launches a BYOND compiler, daemon or client, installs prerequisites,
reads user credentials/profiles, or changes network/security settings.

The report separates normal imports from delay imports and logical API sets.
It records exact file/architecture/hash observations in the extracted bin and
bounded Windows system locations, with at most 128 paths and 256 MiB read.
Unresolved providers are facts from those locations, not a complete emulation
of Windows KnownDLL, API-set, WinSxS or runtime LoadLibrary resolution. A file
inventory cannot identify retrospectively which DLL was absent on another VM.
Native readiness is always false. Output is capped at 4 MiB and failures are
retained; no automatic installation or runtime retry follows a missing provider.

## Microsoft x86 dependency data preparation (source only)

`d3dx_data.py` is deliberately not registered in a workflow or native runner.
Its synthetic offline tests are registered alongside the existing preparation
contracts. Only the three exact reviewed preparation paths are excluded from
introduced native-suite discovery; neighboring executable files remain eligible.
The reviewed proposal is data preparation, not prerequisite installation or an
engine retry. It uses only Microsoft's fixed NuGet package
`Microsoft.DXSDK.D3DX 9.29.952.8`. `tools/byond/d3dx-package.json` retains the
official registration/catalog URLs and raw-metadata SHA256s, catalog package
size/SHA512, exact selected member sizes, and the original 13-file BYOND binding
from audit run 41502784807. These are expected pins, not measured DLL hashes.

After specific publication/acquisition authorization, a future isolated hosted
Windows manual job can call the helper with the exact source/workflow SHA,
attempt 1, `D3DX_DATA_PREPARE=approved-data-only`, an already prepared immutable
BYOND input bin below `RUNNER_TEMP`, and a new output at
`RUNNER_TEMP/tree-d3dx-data`. The CLI also requires `--acquire-data`. No workflow
or dispatch is added here. A future job must have a five-minute outer limit.

```text
<verified Python> -B tests/tree_refresh_native/d3dx_data.py --source <exact SHA> --input-bin <original private BYOND bin> --output <RUNNER_TEMP/tree-d3dx-data> --acquire-data
```

There is one exact HTTPS package request, no proxy/credential use, redirect,
retry, alternate source or implicit prerequisite acquisition. Acquisition has a
120-second deadline with 20-second read timeouts; normal preparation is capped
at 240 seconds, leaving an original-input verification reserve through 270
seconds and final report time inside the future 300-second job limit. New
package, selected files and report share 16 MiB, with a 128 KiB report ceiling.
Input BYOND files are read-only preexisting data and are not copied into this
output. Their exact inventory, sizes and SHA256s are checked before and after.

The catalog size and SHA512 are verified before opening the ZIP. Member paths,
case-insensitive duplicates, links/reparse attributes, encryption, compression,
counts, selected sizes and CRCs are checked. Only x86 `D3DX9_43.dll`, plus
`LICENSE.txt`, `NOTICE.md` and `.signature.p7s`, are staged. No NuGet/MSBuild
script, target, installer or DLL entrypoint is evaluated. The x86
`D3DCompiler_43.dll` is included only when D3DX's actual normal or delay import
table names it; no runtime LoadLibrary requirement is guessed. All selected
files retain exact bytes and measured SHA256. PE architecture/import tables and
why the compiler companion was included are recorded. Delay imports remain
labelled; API sets, system resolution and dynamic loading are not emulated.

`d3dx-signature.ps1` asks the existing Windows Authenticode verifier for metadata
without loading the target. The helper requires a valid embedded Microsoft
Corporation signature with timestamp certificate and records certificate
SHA256s, issuer, subject, validity dates and status. Signature commands have a
20-second timeout and 32 KiB output bound. Existing Windows trust validation may
retrieve trust/revocation metadata over the network. That behavior is not an
exact-URL-only claim: any future execution authorization must account for it.
An unavailable/untrusted result fails; no trust-store, revocation or security
policy is weakened. No verifier command has been run on a Microsoft payload in
this source-only task. Package signature bytes are preserved, not separately
claimed NuGet-signature validation.

Successful preparation reports `native_ready=false`, `native_executed=false`
and `software_installed=false`. Failures retain their report and original-input
verification. Staging is separate from the BYOND bin; a future reviewed combined
toolchain manifest and explicit execution approval are required before any
application-local placement or loader/game test. Nothing writes System32,
SysWOW64, user BYOND, PATH, registry, profiles, credentials, or Gaia.

Firewall containment is outside this patch. Any future security-setting action
requires its own exact program-path/rule-name/VM/deadline approval, verification
and owned-rule cleanup. The native socket oracle is unchanged, and no endpoint
allowlist, global rule or policy change is added here.

Offline verification uses synthetic ZIP/PE data and injected acquisition/trust
adapters, with sockets and external commands disabled:

```text
<verified Python> -B tests/tree_refresh_native/test_d3dx_data.py -v
```

Primary documentation: [Microsoft-owned package and redistribution terms](https://www.nuget.org/packages/Microsoft.DXSDK.D3DX/9.29.952.8),
[Microsoft's application-local package guidance](https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/packaging/packaging-framework-packages?view=gdk-2604),
[Windows signature metadata](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-authenticodesignature?view=powershell-7.5).
The earlier audit's setup-log/environment image-version discrepancy remains
unresolved; this preparation does not attribute the historical loader failure.
