# Saved roof-area recovery (draft, native execution held)

Normal roofs replace turf membership with a canonical roofed climate area.
The serializer stores an area reference as its first turf coordinate and type;
the durable header also captures area fields at that anchor. Fresh startup has
the unroofed map there. Rejecting that reference against startup topology before
loading any saved roofs makes a valid historical generation unrecoverable.
The map and relevant serializer/validator/roof code were unchanged between the
investigated writer and reader revisions. This is source evidence, not a native
baseline or proof that every historical payload is valid.

The candidate projects only direct saved turf contents whose roof type, explicit
scalar `switch_area` and `current_area_type`, current base area and supported
climate agree. It validates ordinary and durable references against that
prospective topology without creating areas or objects. After normal preflight
and map clearing, it restores roof membership before decoding graph fields.
Roof constructors reuse this topology; recursively referenced roofs keep their
validated turf and identity within the current level's entry namespace. Ordinary area checks remain strict. Ambiguous
placements, missing metadata, unsupported climates and multiple explicit area
instances of one roof/base type, including empty instances, fail closed instead
of being merged silently. Preflight retains the exact area object; import
rechecks uniqueness and that same identity before changing any membership.

BYOND normally has one canonical instance per area type; explicit `new /area()`
with a null location can create additional instances. The compatibility path
does not infer such additional instances from an old anchor/type reference.
Reference: https://www.byond.com/docs/ref/info.html#/area

## Offline preparation

```
<verified-python> -B -m unittest discover -s tests/roof_area_recovery -p 'test_*.py' -v
<verified-python> -B tests/world_save/run-durable-world.py --roof-areas --prepare-only
<verified-python> -B tests/world_save/run-durable-world.py --roof-areas --prepare-only --roof-control projection
<verified-python> -B tests/world_save/run-durable-world.py --roof-areas --prepare-only --roof-control cleanup-namespace
```

The preparer disables normal game startup and omits every DMM. It retains a
full-source DME and a tiny synthetic 8x8x2 writer/reader fixture. It copies no
configuration, credentials, production save or player data. Its native execution
entry is deliberately refused. Existing full-game CI compilation does not
compile or execute the new fixture. Offline passes do not establish recovery.

## Native validation required before merge/deployment

Use a separately reviewed immutable packet and normal resource admission.
No native execution is requested by this document or enabled by the preparer.
The separately prepared `run_linux.py` runner is not invoked by any workflow.
The exact proposed insertion is `ci-steps.yml.example`; it is review-only and
is not an active workflow. It reuses the existing Linux build job after its
BYOND bootstrap/full-game compile, `contents: read`, exact PR-head checkout and
disabled credential persistence. It selects only introduced roof tests on
opened/synchronize/reopened PR events, never body edits, push or manual dispatch.
The three packets run sequentially and stop on the first failure, without retries.
The enclosing step is bounded to 40 minutes; native work plus cleanup remains
990 + 330 + 330 seconds. Preparation and input verification precede those native
deadlines. No change to production/private data or native session is involved.

Windows-prepared request hashes are review records, not portable execution
requests. CI regenerates each packet using the exact reviewed Git commit and
generator, then freezes and passes its actual Linux `request.json` SHA256 to the
executor. Every raw generated-input hash remains enforced. The request also
records `execution_contract_sha256`: head, source Git-blob hashes, engine pins,
variant, modes, caps, port, generated DM code roles, deterministic catalog and DME.
Only the generated UUID filename prefix in the DME and its text line endings are
normalized in this additional contract fingerprint. Generated DM bytes themselves
are hashed unchanged (the preparer writes LF). Preparation timestamps, local paths
and log metadata are excluded from that fingerprint but remain raw-hash sealed
where included in the actual request. This is explicit source-contract execution,
not substitution of a Linux request under an approved Windows request hash.

`NATIVE_USED` inside a new exclusive output directory alone only prevents reuse
of that output. Before creating any output or native child the runner now creates
`$RUNNER_TEMP/roof-area-request-claims/<actual-request-SHA256>.json` with exclusive
file creation. The claim is retained on success, failure or uncertain interruption;
another output or copied packet with the same request hash is rejected on that
runner. The claim binds head, output and GitHub run/attempt identifiers. This is
not a global replay registry across disposable GitHub VMs: a fresh CI run prepares
a new request, records run/attempt provenance and must be reviewed as a distinct
invocation. Neither a claim nor packet preparation is an execution grant.

Artifact retention covers only the fresh synthetic packet/output directories and
these dedicated request claims, including hidden generated DM files, compiled
pair, logs, per-mode synthetic saves and receipts. Each invocation enforces its
120 MiB generated-artifact budget (at most 360 MiB across three successful packets,
including each packet's accounted frozen inputs); retention is seven days. No
repository config directory, environment dump, token or production save is uploaded.

Its execution gate requires isolated Linux PR CI for Civ13/Civ13, the existing
installed BYOND516.1681 engine, a new output under RUNNER_TEMP, exact source head,
an external request SHA256 and the fixed packet contract. It denies Desktop
execution before reading the packet or creating output.

It reuses the accepted collector runner's retained-leader WNOWAIT identity,
process-group cleanup, native census and owned-socket inspection functions.
Engine hashes are pinned to the accepted CI40019637842/artifact12530610922
manifest: DreamMaker `b9f175ac9a24662a9ba6fa64652b669aff77ff4787b81b84497dff544f166677`,
DreamDaemon `112b3f4e74b95d82b7e117de35fae70f773e4b770a3302f8c0c33758f9e2f4e1`.
Child environments contain only engine paths, isolated HOME/TMPDIR and locale.
No GitHub credentials or native user session variables are inherited.
Each synthetic case receives only the tracked public `config/tips.txt` and
`config/names` inputs. Token, admin and operator configuration is never staged.

Offline packet preparation, one new directory per variant:

```
<verified-python> -I -B tests/roof_area_recovery/run_linux.py --prepare-only --packet-dir <new-path> --expected-head <reviewed-commit> --variant main
```

Repeat for variants `projection` and `cleanup-namespace`. Preparation records
all canonical Git-blob source hashes, deterministic public crafting-catalog
output, every prepared input hash, engine pins, caps and exact phase sequence.
It never invokes the compiler or daemon. Source and resource review is required
before using the separate CI-only execution entry; packet creation is not a grant.
After that review, its fixed execution command is:

```
python3 -I -B tests/roof_area_recovery/run_linux.py --packet-dir <frozen-packet> --expected-head <same-reviewed-commit> --request-sha256 <reviewed-request-sha256> --output <new-RUNNER_TEMP-child> --byond-bin "$GITHUB_WORKSPACE/BYOND/byond/bin"
```

This command is documentation, not authorization or an enabled CI step. Run the
three variants sequentially with fresh output directories. The caller never
rewrites a request or retries a failed native invocation.
Proposed limits: one compiler at a time (180s), then one child at a time (60s
per mode), 30s total cleanup allowance, 1024 MiB per compiler/daemon process,
120 MiB aggregate generated-artifact budget, logs capped at 1 MiB per phase,
and an outer 990s deadline for the 13 main modes below. Each independently
compiled old-defect or cleanup-namespace control has its own 330s outer cap
(180s compile + two 60s children + 30s cleanup). Run those three packets
sequentially, with no shared grant or automatic retry. Any cap failure
rejects acceptance and retains evidence. Ownership, child exit and absence of
remaining listeners must be checked externally; in-world port closure alone is
not enough. Startup uses only `127.0.0.1:19327`, then the
fixture closes it, rejects reopening and rejects every client. No public probes.
Before any fixture body runs, a ten-second file handshake requires external
owned-socket closure acknowledgement. Failure or missing acknowledgement rejects
the phase. Every child has hard address-space/CPU/file/core limits, observed
single-child membership and file/log/controller budgets. The native source and
compiled pair are rehashed, writer payloads are preserved, and owned cleanup plus
the final native census must succeed. Logs and failed fixture copies are retained.

1. Compile full production sources with the synthetic fixture on BYOND516.1681.
2. Fresh `roof_mode=write` creates real supported roofs on two levels and a
   disabled-roof subtype, ordinary object area
   references, nested list aliases/area keys and a durable metadata area edge.
   It exports a real generation and validates the writer's still-roofed world.
   It then clears bookkeeping, destroys a roof through the real Destroy path,
   checks the restored base area, and validates the unchanged disk generation
   against that altered topology. `write-covered` does the same.
3. Retain and hash those synthetic payloads. Copy them separately for each mode.
4. Fresh `roof_mode=read` starts unroofed, preflights without world mutation,
   then imports and checks exact area/roof aliases, roof location/settings,
   durable area fields, operation release and unchanged generation.
5. Nine fresh copy-only negative modes: `missing-roof`, `wrong-base`,
   `missing-scalar`, `disabled-roof`, `unrelated-area`, `duplicate-area`,
   `duplicate-placement`, `empty-instance`, `postflight-empty`.
   Each must reject before world mutation. Preserve their altered fixture copies.
6. Fresh `write-covered` then `read-covered` uses a roof on every synthetic turf.
   Preflight must accept the absent unroofed base-area row, preserve one shared
   roof area and check its durable fields. Constructor overlays, exact roof
   counts and later Destroy restoring the original base area are checked in both
   positive reader cases. Ordinary `read` also executes the actual cleanup
   predicate with equal numeric refs on different z-levels, including the
   positive same-z retention case, and verifies disabled-roof settings/topology.
7. Old-defect control: `--roof-control projection` prepares a source copy with
   only the projection call removed. Run `write-roofed` then `old-defect`. This
   writer validates before AND after bookkeeping cleanup without removing its
   roof, so it cannot fail solely because the projection is absent. The fresh
   reader must reproduce the exact area-reference rejection before import.
   Do not call an unrelated crash a pass.
8. Cleanup-namespace control: `--roof-control cleanup-namespace` replaces only
   `is_loaded_validated_roof` in a source copy with the old unscoped coordinate/ref predicate. Run
   `write-roofed` then `read`; it must reach and fail the named cross-z collision check.
   The original candidate must pass that same check. This control must not be
   accepted based on any other exception.

Retain source/DME/patch hashes, compiler output, per-mode result/log hashes,
process birth/exit identities, external socket observations and cleanup receipts.
The proposed limits, fixtures and offline packets are not an execution grant.

## Private generation acceptance

Original saved payloads and backups remain untouched. After reviewed synthetic
native acceptance and source review, validate the exact existing generation using
the separately authorized canonical compile/restore lifecycle. A successful full
import, readiness, advancing ticks and absence of recovery errors are still
required. No fresh world, other save, blanket type-check relaxation or save
rewrite substitutes for that acceptance.
