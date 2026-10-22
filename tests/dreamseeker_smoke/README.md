# Guest renderer feasibility only

This separate Windows CI experiment asks whether the hosted x64 desktop can show
and capture actual DreamSeeker 516.1681 map pixels. It does NOT test the Civ13
compositor, oversized trees, native visibility, weather or persistence. No smoke
receipt may satisfy `light_plane_composition/verify_render.py`.

The official portable archive and all executable/DLL bytes are SHA256 pinned in
`vendor.json`. The workflow uses a disposable windows-2022 runner, read-only token,
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
approval. Existing process, socket and resource checks remain required. This
source correction does not resolve vendor download failures or establish native
renderer acceptance.
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

## Explicit local-installed mode (source draft, no execution admitted)

The hosted path and its official archive request are unchanged. Its recorded
HTTP 403 remains failed. This separate mode uses existing installed files only;
it does not retry, mirror or replace that request or the consumed Linux attempt.
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
| `installed_manifest` | Existing read-only installed identity record, SHA256 `1aa0306fade5defcdac743614bcc27a441b9f8f23c519a9a7cabc713007725c3` |
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
`guest=1;version=516;build=1681` receipt. It does not attach/control an unrelated
client or relax the hosted guest oracle. Whether guest startup works with that
profile remains a native acceptance question; an unexpected prompt is a stop.

Before launch, verify all 18 installed names, sizes and hashes against the pinned
identity record. Stage only the 12 existing vendor-manifest files plus the three
recorded VC120 runtime DLLs (`mfc120u`, `msvcp120`, `msvcr120`) into a new private
bin directory. This conservative set is not proven minimal dependency closure.
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
compiler, daemon, client, UI or socket was exercised to prepare this source draft.

## Workflow selection guard (unpublished source)

Pull requests matching this workflow or any smoke file select only the standard
`windows-2022` offline-contracts job. Selection uses the full PR three-dot diff;
a later unrelated-only push does not erase earlier smoke changes. The native
job requires successful offline contracts, `workflow_dispatch`, boolean
`run_native: true` (default false), and `selected_sha` equal to the dispatch's
exact `github.sha`. The SHA input is a consistency check, not execution authority.
The original hosted installer and request remain unchanged. Do not dispatch it
without separate exact authorization; neither source review nor publication
authorizes another attempt at the recorded vendor 403.

Offline controls read the actual workflow job blocks and path selectors, exercise
the frozen full-PR path set, default-off/incorrect-SHA cases and mutations removing
the native guard/event restriction. Their expression evaluator deliberately
supports only this small equality conjunction, not general YAML or all GitHub
expressions. Actual Actions parsing/selection still requires reviewed publication
and CI evidence. This draft has neither been pushed nor dispatched.

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
