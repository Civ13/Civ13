# Guest renderer feasibility only

## Current source status (2026-10-29)

This PR adds standalone, opt-in verification tooling. The current reconciliation
retains master `8b4c3f5ca76e4ed78927819e9b4c50873ec9b19e` for all production code,
lighting/persistence tests, CI selection and agent guidance. Earlier inherited
lighting changes are already superseded by accepted master changes; this probe
does not reintroduce them or activate a renderer. The completed tree screenshots
in #3398 belong to that feature and do not establish this fixture's acceptance.

The hosted source targets 516.1688. Local-installed execution remains deliberately
disabled by the unset reviewed-manifest constants. Its future staging contract
also needs a reviewed mapping for VC140 system dependencies; a matching payload
directory alone is insufficient. This is not a working local execution route.
All five spent attempts and their failed/uncertain outcomes stay preserved.

## Terminal receipt retention (#3323)

Terminal JSON stays strictly below 64 KiB and uses compact serialization.
After all owned cleanup attempts, the runner atomically saves a failed cleanup
checkpoint and `receipt.json` before optional aggregation. It independently
retains the source hashes in `source-receipt.json` and the actual phase capture
hashes/guest handshake in `capture-receipt.json`. This smoke has no gameplay
take or viewport witness; these files must not be represented as those claims.

A sibling temporary file is flushed/fsynced, the original entry budget is
checked, and the failed checkpoint is replaced atomically only when all core
evidence is retained and the full receipt fits. Successful outcomes also require
three confirmed cleanup roles, the exact guest/build handshake, both phase
images and their unchanged hashes. Overflow, missing evidence, expired time or
write/replace failure remains failed; the primary exception is still raised.
An oversized cleanup checkpoint uses explicit failure summaries/hashes and
retains unconfirmed cleanup rather than claiming it succeeded.

`terminal_committed: true` identifies a complete terminal document, including a
complete failed outcome. It is not acceptance on its own. The independent
cleanup checkpoint deliberately retains a failed/pending overall result while
recording the actual per-role cleanup facts. V47's historical missing evidence
and uncertainty remain unchanged.

Offline coverage: `py -3.12 -B -m unittest discover -s tests/dreamseeker_smoke
-p "test_*.py"`. Tests use synthetic files, injected adapters and temporary
storage; they do not launch native tools or capture a desktop. Runtime admission,
165-second budget, size/resource limits and all launch/network checks are unchanged.

Native startup, exact pixels and cleanup for this source are unverified report
items. Source publication or regular-PR status grants no local attempt, hosted
dispatch, dependency setup, profile change or production operation. The existing
capture owner remains responsible for any separately admitted future run.

This separate Windows CI experiment asks whether the hosted x64 desktop can show
and capture actual DreamSeeker 516.1688 map pixels. It does NOT test the Civ13
compositor, oversized trees, native visibility, weather or persistence. No smoke
receipt may satisfy `light_plane_composition/verify_render.py`.

The exact reference-observed 516.1688 mirror archive and executable/DLL bytes
are SHA256 pinned in `vendor.json`; this is not a vendor-authenticated checksum. The workflow uses a disposable windows-2022 runner, read-only token,
no checkout credentials, no user secrets, no account/pager startup, no firewall,
registry, security-policy or display-driver changes. The guest URL uses the
vendor-documented `##guest` option. A login/permission dialog is never accepted.

Each compiler, daemon and client starts suspended in its own kill-on-close Job
with one active process allowed, so no pager or other child can start. These are
three distinct Jobs; the visible client is deliberately NOT the hidden/no-socket
HUD test. Each process has a 512MiB memory cap and a monitored 60 CPU-second cap;
the harness has one entry-anchored 165-second cooperative envelope and the
workflow a ten-minute outer bound. Preparation never restarts that envelope.
Retained process handles are used for cleanup and socket ownership checks.
The fresh process environment excludes inherited environment variables; this
does not isolate Windows registry, existing BYOND authentication or preferences.

The daemon is explicitly started with `-ip 127.0.0.1`, invisible, `-trusted` and no
webclient. Its exact loopback-only listener must be observed before client launch.
Trusted mode follows the repository's daemon policy; it does not grant execution
approval. Existing process, socket and resource checks remain required. The
historical 1681 download failure is retained; the active source uses the separately
pinned 1688 mirror. Download identity checks do not establish native acceptance.
Only one loopback guest is admitted. An unexpected local address, remote peer,
listener, UDP endpoint, child, window or prompt fails the run. Socket polling is
an observation/control, not an OS network sandbox or proof against transient
connections between samples. No security settings are changed to strengthen it.
The parent must review this limitation before publication.

A generated white tile is an INPUT sprite. The native fixture tints tiles red,
then blue after the first capture, retaining a green actor in the center. The
harness captures the actual foreground client rectangle from the desktop twice
per phase and requires stable pixel bytes with the expected phase/actor colors.
It saves those unmodified PNGs, exact source/vendor hashes and owned cleanup
receipts. Synthetic unit images only test the color oracle. They are never saved
as native captures. No renderer compatibility is established before CI runs.

Only evidence-directory logs (1MiB monitored bound each), two bounded PNGs and
JSON receipts are uploaded, not compiled resource caches or vendor binaries.
Any failure stops here; do not use account login, administrator overrides,
firewall changes or RDP to make the hosted smoke pass.

## Explicit local-installed scaffold (disabled, no execution admitted)

The historical 1681 HTTP403 and all five later spent attempts remain failed
evidence. The active 1688 migration is described in MIGRATION-1688.md; neither
reference capture run accepts this fixture. Local mode uses existing installed
files only and is held until a fresh1688 identity record is independently reviewed.
Never set `GITHUB_ACTIONS` to evade the hosted restriction.

Local mode requires both `--local-admission PATH` and
`--reviewed-admission-sha256 DIGEST`. Supplying no packet does not enable local
execution. The digest must be obtained from independent review of the exact
packet and source. Matching a self-authored digest or JSON approval flags is not
human approval, genuine profile verification or resource admission. The code
cannot authenticate the named reviewers or validate their external evidence.
Do not generate a runnable packet until the resource/desktop owner has accepted
the exact plan. No valid packet is supplied by this change or by its tests.

The packet is a bounded JSON object with these required contracts:

| Fields | Required contents |
| --- | --- |
| `schema`, `scope`, `one_use_id` | `1`, `dreamseeker-smoke-local-installed`, canonical unique UUID |
| `task_root`, `output`, `ledger` | Existing task-owned root, exact fresh absolute output, existing durable ledger inside that root and outside output |
| `host`, `account` | Exact `COMPUTERNAME` and `USERDOMAIN` + backslash + `USERNAME` |
| `source_sha256` | Exact `source_identity()` map of every regular fixture-directory file, including this README and tests |
| `python` | Exact resolved interpreter `path` and executable `sha256` |
| `pillow_version`, `pillow_sha256` | Installed Pillow version and `pillow_identity()` map for package initializer, Image, ImageGrab and compiled Image core; not an entire OS/dependency attestation |
| `installed_manifest` | Fresh1688 installed hash and count/size contract pending review; active constants are `None` |
| `issued_unix`, `expires_unix` | Numeric UTC seconds, current admission, at most 300 seconds apart |
| `limits` | `run_seconds:150`, `cleanup_seconds_per_job:5`, `cpu_seconds_per_process:60`, `process_private_bytes:536870912`, `watcher_private_bytes:134217728` |
| `review` | Nonempty `reference`, `reviewer`, `resource_owner`, `executor`, `desktop_owner`; true `native_execution_approved`, `exclusive_desktop_approved`, `socket_polling_limitation_accepted` |
| `profile` | Concrete decision and external evidence as described below |
| `resources` | `measured_unix` at most 60 seconds old, measured `free_ram_bytes` at least 2GiB, `free_disk_bytes` at least 1GiB, true `cpu_headroom_accepted` |

`profile` requires a nonempty `evidence_reference` and either:

- `decision: isolated_verified`, with empty `accepted_effects`, supported by
  actual external verification rather than environment-directory redirection.
- `decision: shared_effects_explicitly_accepted`, with `accepted_effects` equal
  to the exact four strings in `SHARED_EFFECTS` in run.py. This supports an
  admitted existing profile: authentication/preferences may be shared, caches
  and recent connections may be written, and shared screenshots may be written.
  Account/profile isolation is not mandatory. Existing settings are preserved;
  no login, logout, credential, registry or security modification is proposed.
  The evidence reference may cite applicable standing user authorization; this
  is not a demand for repeated human permission for an already authorized use.

Existing-session permission permits use of an existing profile when admitted;
it does not make an arbitrary running client fixture-owned. This adapter still
creates and retains its own guest client process and verifies the exact
`guest=1;version=516;build=1688` receipt. It does not attach/control an unrelated
client or relax the hosted guest oracle. Whether guest startup works with that
profile remains a native acceptance question; an unexpected prompt is a stop.

Before local admission can resume, review the new installed manifest hash and
its exact file count/total size. The previous1681 record hash
`1aa0306fade5defcdac743614bcc27a441b9f8f23c519a9a7cabc713007725c3` remains historical.
Stage only the12 vendor files and reviewed VC140 DLLs (`mfc140u`, `msvcp140`,
`vcruntime140`) into a fresh private bin directory. Read-only checks require the
two pinned x86 DirectX DLLs in the actual Windows system directory before any
native process; no installer or app-local DLL fallback is invoked. This conservative set is not proven minimal dependency closure.
No downloader or fallback is called in local mode. Extra installed/staged files,
changed bytes, duplicate JSON keys, stale resources, changed source/interpreter
or dependency identities deny admission. Live free RAM and disk are also checked
before each process phase. CPU availability remains the resource owner's actual
admission; neither a JSON flag nor these checks reserves the host.

After validation but before the first native process creation, exclusively create
`ledger/<one_use_id>.json`, flush and fsync it. Retain this consumed receipt even
if the first launch fails. Later phases in that invocation verify it unchanged;
a new invocation cannot reuse it. No automatic retry, receipt deletion or ledger
rotation is permitted. The ledger is not tamper-proof against a local actor who
can delete it; approval and task directory ownership remain operational duties.
Path/hash checks are not descriptor-pinned protection against concurrent local
filesystem mutation. Keep the task directory and installed toolchain quiescent.

The proposed one-use execution is one compiler, one trusted daemon and one owned
guest client with the existing three one-process Jobs and retained-handle cleanup.
The standalone 7x7 fixture uses no Gaia source, saves or production session data.
The shared budget starts at `run()` entry, before admission/source/toolchain
identity work. Its entire 165-second envelope contracts to the earliest reviewed
UTC grant expiry and its entry-anchored monotonic equivalent. A forward UTC jump
permanently contracts the monotonic allowance; rolling UTC back cannot replenish
it. Work has a nominal 150-second ceiling, but stops early to retain 15 seconds
for the three cleanup waits and one second for diagnostic receipt finalization
(at most 149 seconds of work with a full 165-second grant). A shorter grant stops
work earlier; a grant with no work remaining after reserves is rejected. No
preparation, phase or cleanup operation starts a new allocation.

The same cheap budget/admission gate runs after slow identity/resource/hash/fsync
preparation, throughout active watch/capture/phase handling and before success.
`Adapter.open` and `Adapter.launch` require an explicit guard, supplied for both
hosted and local modes, immediately before the actual `CreateJobObjectW` and
`CreateProcessW` calls. Launch checks again before resuming the retained suspended
process. There is no missing-callback local fallback. Expiry after consuming the
one-use receipt never removes that receipt or permits a retry. Resource
measurements must remain fresh during the admitted work.

The runner registers each adapter before preflight or potentially partial Job
setup. Cleanup independently attempts every registered owner in reverse order;
each wait is at most five seconds and is clamped to the remaining shared grant
less the receipt reserve. Expired grants still trigger owned termination/handle
cleanup attempts with zero wait, never a fresh five-second allowance. A cleanup
exception cannot skip later owners or replace the original run exception.
Bounded secondary failures and each owner's confirmed/unconfirmed outcome are
recorded, with a best-effort receipt even on failure. Receipt I/O failure is
reported alongside the primary error; one corrective diagnostic write is allowed,
never a process/run retry. Receipt-write budget overrun changes its result to
failure and cannot produce successful runner return.
The 512MiB per-process cap is hard; CPU, socket and log checks are sampled, and
the 128MiB watcher check is preflight, not a hard parent cap. No outer local
supervisor is implemented here, so a blocked OS call is not a hard 165-second
termination guarantee. Zero-wait termination and diagnostic writes can themselves
return after expiry; those are fail-closed cleanup/finalization, never native
acceptance or authority for another action. The resource owner must account for
that limitation.

The desktop owner must allocate the exact capture interval and accept foreground
activation of only this owned fixture window. Unmodified red/blue captures are
needed because actual native rendering is the uncertain contract. Existing pixel,
guest/build, owned-window and cleanup checks remain unchanged. Success would
establish only this smoke, never lighting composition or NPC acceptance. No local
compiler, daemon, client, UI or socket was exercised for this reconciliation.

## Workflow selection guard

Pull requests matching this workflow or any smoke file select only the standard
`windows-2022` offline-contracts job. Selection uses the full PR three-dot diff;
a later unrelated-only push does not erase earlier smoke changes. The native
job requires successful offline contracts, `workflow_dispatch`, boolean
`run_native: true` (default false), and `selected_sha` equal to the dispatch's
exact `github.sha`. The SHA input is a consistency check, not execution authority.
The hosted installer uses the pinned 1688 mirror; historical requests stay recorded.
Do not dispatch it without separate exact authorization; neither source review
nor publication authorizes another native attempt.

Offline controls read the actual workflow job blocks and path selectors, exercise
the frozen full-PR path set, default-off/incorrect-SHA cases and mutations removing
the native guard/event restriction. Their expression evaluator deliberately
supports only this small equality conjunction, not general YAML or all GitHub
expressions. Actual Actions parsing/selection is checked by ordinary PR CI. A
successful offline-contracts job and skipped guest-renderer job establish source
contracts only; no native dispatch is part of this reconciliation.

## Proposed isolated local controller runtime

Local admission additionally binds a complete `runtime` contract: normal task-local
venv without system site packages, launched with `-E -s -B`; exact sys.path, prefix,
base prefix, executable, pyvenv.cfg values, flags and site inventory. Only byte-verified
Pillow 10.4.0 and its complete metadata/license closure are staged; optional NumPy
is naturally absent. No import blocker or modified Pillow is used. The manifest
binds every regular venv file, base Lib excluding unreachable site-packages (including bytecode caches),
base DLLs, and all base-root executable/runtime DLL/zip files. -B disables writes, not cache reads. Reject .pth files,
reparse/symlink entries, extra site packages, changed bytes or ambient paths.
This is not a hermetic interpreter: reviewed base Python and OS DLL dependencies
remain external and must be reported. An independent complete runtime observation
and offline PE dependency review are required before any execution admission.
Normal setup/diagnostics are separately bounded; this proposal stages nothing and
does not renew the spent native attempt or change either memory cap.

The small admission `runtime` field contains only absolute `manifest` and its
independently reviewed `sha256`. A bounded separate JSON manifest contains the
complete layout and expected observation. Its bytes and all runtime dependencies
are reverified at admission and before each native phase; changes deny execution.
This avoids exceeding the admission's existing 64 KiB bound. The manifest itself
is limited to 16 MiB, rejects duplicate keys and symlink/reparse entries.

The exact pinned base-prefix root is a legitimate normal-venv sys.path entry;
arbitrary parents or other site directories are rejected. Validation occurs
after Python startup/imports and cannot undo malicious startup .pth execution.
It is an integrity/admission check, not a Python sandbox: trusted task-owned
staging and prelaunch inventory review remain required. File checks are snapshots,
not descriptor-pinned prevention of concurrent filesystem mutation. Keep runtime
and base dependencies quiescent. No runtime preparer or native admission is
issued by this source proposal; reviewed normal-venv preparation and offline PE
dependency closure remain prerequisites for any concrete runtime manifest.

Retained process identity is captured from the Job-owned suspended child before
ResumeThread, including image, PID and creation time, and bound to the retained
process/thread handles. Exit reporting uses that verified identity without a
post-exit image query. Identity capture failure prevents resume. Cleanup records
Job termination/close and retained wait/exit-code outcomes before identity/CPU
enrichment. Thread/process handle-close outcomes are recorded afterward in
finally, including when enrichment fails. Errors still fail cleanup acceptance
without erasing successful primitive observations. This does not establish historical
cleanup or rendering acceptance for earlier failed attempts.

The standalone compile phase selects the pinned console `dm.exe` entry point
with `-max_errors 0 fixture.dme`, matching the existing world-save runner. The
compiler must still exit zero, emit `0 errors, 0 warnings`, and produce the DMB.
The GUI `dreammaker.exe` entry point is rejected by an injected orchestration
regression. Static entry-point evidence and these tests do not establish the
cause of a prior exit, native compilation, or environment compatibility.

The standalone server phase selects the pinned console `dd.exe` entry point,
matching the existing world-save runner. Loopback, trusted mode, readiness,
listener checks, process ownership and cleanup remain required. An injected
orchestration regression checks the executable and complete server arguments;
its GUI-selector mutant is rejected. Static entry-point evidence supports this
selection but does not establish why the prior GUI server exited, native server
readiness, or renderer acceptance. No environment or profile changes are made.

## Same-command owner envelope (default OFF, source only)

The opt-in `same_command.py` integration avoids an asynchronous message between
resource measurement and native invocation. No runnable envelope or execution
approval is supplied. A future attempt needs new applicable human authority and
an independently reviewed owner-envelope file and SHA256, not any spent grant.
Without `--execute` it refuses before sampling. There is no hosted workflow
activation, automatic retry, background worker, or refresh path.

The independently reviewed bounded JSON envelope has exactly `schema: 1`,
`scope: dreamseeker-smoke-same-command-owner`, `enabled: true`, a nonempty external
`authority_reference`, finite `not_before_unix` / `expires_unix` at most 300 seconds
apart, `dynamic_fields: [issued_unix, expires_unix, resources]`, `sampling_policy`,
and `admission`. The complete ordinary admission template is sealed, including
source hashes for the wrapper, shared budget and tests; Python/runtime/BYOND,
UUID, paths, profile, owners, review decisions and all limits. Only the three
listed fields are null placeholders. The template also retains the sealed
`dependency_record` path/SHA256 from static preparation. No owner, approval,
threshold, identity, path or reference is generated dynamically.

The exact sealed sampling policy requires one second, at least 2GiB available
RAM and 1GiB disk, a finite explicit CPU busy threshold from 0 through 0.25, and
a five-second maximum sample-to-invocation age. Its keys are `sample_seconds`,
`min_free_ram_bytes`, `min_free_disk_bytes`, `max_cpu_busy_fraction`, and
`max_sample_age_seconds`. One supported read-only Windows sample records actual
host/account, RAM/disk, CPU fraction, unchanged input, foreground stability,
input-desktop access and absence of the fixed conflicting process names. A NULL
foreground is allowed when stable and access succeeds. Snapshot enumeration is
bounded; failed, active or conflicting samples stop without another sample.
`cpu_headroom_accepted` is computed true only when the sealed owner's CPU
predicate and all resource/access/conflict predicates pass. It is never an
executor-supplied approval override. The actual full sample is retained.

A durable, exclusive, fsynced `<UUID>.entry.json` claim binds the owner envelope
path/hash and original clocks before sampling. Refusal, collision, uncertain
write or execution failure retains that entry; it cannot be deleted or reused.
This entry differs from the existing native-launch claim, which is still consumed
at its original admission boundary. A preflight entry proves neither a native
start nor acceptance. Final admission, sample and provenance records also use
exclusive names. The final packet SHA256 is DERIVED integrity under the sealed
independent delegation, not independent review by the executor of its own output.

The original shared Budget starts before argument parsing and heavy imports.
Preparation, identity checks, entry claim, sampling, final writes/hashes, harness
admission and owned cleanup all consume that SAME Budget. Its 165-second total,
149-second effective work allowance, 15-second cleanup plus one-second receipt
reserves, UTC contraction, and fixed 60-second admitted resource age are unchanged.
Expiry is bounded by both the sealed owner interval and that original entry.
Immutable-envelope/source checks, sample age and remaining reserves are rechecked
after slow boundaries and immediately before calling the existing harness in the
same interpreter. All per-phase runtime scans and native creation guards remain.

Injected controls cover old 117-second handoff refusal, pre-sample time charging,
actual harness budget reset, owner/source mutation, expiry, UTC rollback,
resource/access/input refusal, uncertain writes, reuse and receipt overrun. These
are offline contracts; they do not prove Windows availability, daemon readiness,
rendering, hard OS preemption, global shared-resource locking or historical
cleanup. Blocking OS calls and the existing sampled network/shared-profile limits
remain. No real sampling, host query, envelope issuance or native execution is
authorized by this source proposal.

The source-only v2 review correction timestamps the EARLIEST component of the
single sample, before process observations and the CPU/input interval. That
immutable timestamp is never replaced by scan-completion time. Collection checks
its five-second age after slow scans and snapshot cleanup as well as before
handoff; an old observation cannot become fresh when a later scan finishes.
The expected final serialized UTF-8 bytes and SHA256 are computed from the
reviewed in-memory admission projection BEFORE writing. Exclusive binary writes
retain those exact bytes; all later integrity checks and the harness receive
that retained expected hash rather than establishing a new seal from a mutable
file. A snapshot cleanup failure is attached to an existing primary refusal;
cleanup-only failure is still fatal. Injected causal controls also run against
the immutable v1 implementation, which must fail all three regressions.

The v3 provenance correction also seals the exclusive entry claim's expected
serialized bytes/hash from its reviewed in-memory projection BEFORE writing.
Entry integrity checks before and after sampling and finalization compare with
that retained expected seal. The first filesystem hash can never legitimize an
altered owner-envelope binding. Its actual-execute rewrite control must fail
against frozen v2 while leaving the owner envelope unchanged.

Premature client/server exit retains the original failure and samples both roles
before cleanup: monotonic observation time, exited status, exit code when
exited, and retained PID/birth/image identity. Diagnostic read errors remain
bounded and cannot replace that failure or skip cleanup. These are failure-time
samples, not exact exit times or proof of first-exit ordering. Historical cleanup
codes remain ambiguous because Job termination assigns exit code1. Mocked
client-only, server-only and both-exit controls provide no new native acceptance;
the existing native hold, capture ownership and one-use admission remain in force.


## 516.1688 migration preparation

See MIGRATION-1688.md for immutable references, changed oracles and proposed
one-shot bounds. Window capture now requires exact224x224,96DPI, visible/nonminimized
foreground ownership, on-screen geometry, sampled9x9 hit ownership and matching
retained identity/geometry before and after the genuine screen read. It never
crops/resizes the captured image or changes DPI/display settings. Pixel equality
checks the complete known7x7 scene, including its centered32x32 green actor.
The fixture fixes native view3/zoom1 and has no production HUD; the tanning HUD
correction is reference context only. No synthetic test pixels are evidence of
rendering. Sampling cannot atomically exclude a transient overlay. Native startup,
DirectX closure, screenshot mapping and exact pixels are unrun for this source.
