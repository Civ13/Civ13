**Historical proposal:** This describes the earlier exact-offset fixture and its original approval status, not the current tile-only fixture. Subsequent authorized synthetic runs are recorded in `docs/human-save-motion-candidate.md`.

# Minimal native evidence proposal - not authorized or run

The offline candidate model accepts a synthetic unlinked human at nonzero x/y
offset, carrying a bag with a nested item, on ordinary floor with a nondense pen.
That is a model acceptance only: `constructors_and_defaults_audited` and the pen
hook assertion are inputs. It is not evidence that the production serializer or
BYOND loader accepts the case.

The source audit finds the default `/atom/CanPass` returns `!density` for the
human restore's nonzero height, while `/obj/item/tape` and stationary guns have
their own overrides. The exact `/obj/item/weapon/pen` and paper paths do not
declare their own `CanPass` in the inspected source; their inherited item
`after_load` registers abandonment state. Constructors, derived defaults, hook
order and native savefile directory semantics still need actual engine checks.
Do not generalize this to all item descendants. There are multiple source
declarations of human `after_load`; compilation and a direct sentinel must
establish which behavior is present in the tested build.

The experimental production source contains an encoded reader for explicit
shape and link scalars, the detached capsule, exact-type floor and pen/paper
occupants, unique slot parents and known reciprocal physical fields. A roster
seal checks the encoded candidate ownership and sets the coverage flag only
after these checks. This code is not compiled or exercised by the Python model;
the branch remains disabled in ordinary builds. `human_spatial_stage.py` now
prepares a full-source candidate with a test-only headless authority seam and
`human_spatial_probe.dm` supplies writer and reader entry points. Neither has
been compiled or executed. `human_spatial_run.py` supplies a Linux driver that
uses the existing owned process-group cleanup and adds sampled resource bounds.
There is no hosted workflow yet, and these files are not CI evidence or a pass.

## Proposed separately admitted synthetic test

After source review and an exact source snapshot, extend the existing isolated
moving-save/world-save fixture rather than using any production data. A bounded
manual job uses the existing 516.1688 bootstrap's full-game compile, a second
fixture compile and up to fourteen sequential synthetic daemon processes, each
with separate temporary storage and retained receipts:

1. Compile the full relevant human/persistence source with a 4x4 or larger
   synthetic world and real constructors. Check exact zero compiler errors and
   preserve warnings; do not substitute the reduced animal-only stubs.
2. Writer: one unlinked human at a nonzero two-axis sub-tile offset, a slotted bag
   containing an item, and a nondense exact-type pen in its four-cell footprint.
   Drive a **headless test-authority** movement transaction and request a handoff between
   pulses; verify it continues. Save
   with the candidate implementation and retain marker, typed field, origin,
   saved containment and hashes. Separate ordinary and restart-owner captures
   are followed by fresh-process readers that compare the exact five-field
   capsule, generation, direct slot and nested item. Named negative cases for a
   wall, dense object, contained or buckled human, persistent pulling, roster
   invalidation, duplicate saved parent, missing roster and unsafe shape default
   require their specific refusal and byte-identical prior generation. If a
   current completion marker remains, it must be byte-identical to the seed and
   cover the complete seed bytes; an old backup cannot excuse a new or mixed
   current generation. They
   require fresh synthetic candidate directories and no real save manipulation.
3. The headless drag probe substitutes only its named actor for the normal
   `client && client.moving` drag predicate in the staged test source. An
   unadapted headless actor must still stop pulling. It checks ordinary drag,
   both completion hooks once and fail-closed leader/follower ownership. It cannot establish connected-client
   input costs, real client identity or live pair adoption behavior. Retain exit
   codes, stdout, stderr, runtime logs and cleanup results.

Reuse the current-pin `tests/movement_save_chunks/correctness.py` and its
`benchmark.py` process controls where applicable, with a reviewed full-human
adapter and no duplicate generic supervisor. Its documented test child limit is
1 GiB address space/RSS sampling and 90 seconds per case; actual feasibility
and cost of full-human compilation under that cap are unknown. Native file IO
is not preempted by logical limits. Do not adopt an obsolete engine fallback.

The existing Windows diagonal runner rejected the engine's startup loopback
listener, so its no-socket rule must not be bypassed. An alternative needs a
separately reviewed current-pin isolation profile. A Linux disposable runner
may briefly bind loopback before `world/New`; `-ip 127.0.0.1`, `-nowebclient`
and source closure are not an OS network/egress sandbox. Exact listener,
network, temporary filesystem, process ownership/cleanup and timeout behavior
must be disclosed with the requested authorization. No external services,
credentials, production saves, live account or live server are involved.

The proposed manually selected job in `moving-save-chunks.yml` uses one disposable
Ubuntu runner, checkout with
persisted credentials disabled, exact immutable head verification, and the
repository's 516.1688 Linux archive pin (SHA-256
`16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9`).
The proposal uses a 40-minute job timeout, an 18-minute bootstrap step and a
15-minute fixture step, leaving time for checkout, offline checks and evidence
upload. The checked-out dispatch SHA must equal the separately approved commit;
the scope digest must independently match the approved overlay/driver bytes.
The approval-bound values have to be resolved after the final commit exists.
The driver uses a 90-second child deadline and a 10-minute native-sequence
watchdog checked at launch and sampling boundaries; Python file I/O and up to
10 seconds of child cleanup can extend it. An external job timeout is needed
for a hard wall-clock limit. Each child has a 1 GiB address-space limit and
sampled RSS, a 256 MiB hard
per-file limit, a sampled 256 MiB output limit per working directory and sampled 8 MiB logs
(the reused diagnostic helper also rejects logs above 4 MiB). Samples can
overshoot; there is no hard total-disk quota across the job. Up to fourteen
runtime directories can each reach the sampled limit, plus the staged source
(capped at 2 GiB) and compile output. A hosted job also needs a separate overall
timeout encompassing staging and any approved provisioning. The process-group helper
retains the leader until group cleanup, but descendants that deliberately leave
the group are not contained. It uses a minimal child environment and does not
inherit tokens. A disposable hosted runner is not an OS egress sandbox.

The existing `scripts/travis_pre_byond.sh` adds the i386 architecture, downloads
APT metadata and installs i386 runtime packages, downloads the repository-release
archive, runs `make here`, generates the crafting catalog and compiles the full
game once with a 300-second timeout. The fixture then compiles once more. This
bootstrap has no fixture driver's per-process 1 GiB limit or sampled disk cap;
it runs on the disposable hosted runner under the job and step timeouts. The
archive identity is rechecked before every fixture process. The fixture driver
itself does not download, and requires a new output directory, pinned binary and
archive paths, an independently reviewed full head SHA and an independently
reviewed overlay/driver scope SHA-256. The workflow validates both values before
the bootstrap. Its checkout token is read-only and is not persisted; no user
secrets are configured, and fixture child processes get a minimal environment.
Hosted-runner infrastructure and network access are not an OS security sandbox.

## Automatic checks triggered by publishing this patch

The manual human-spatial job is skipped for pull requests. The existing
`moving-save-chunks.yml` pull-request job still runs for these persistence and
fixture paths: its ordinary correctness and memory matrix can invoke up to nine
compiles (the bootstrap plus six correctness and two benchmark builds) and 42
synthetic daemons, subject to its existing 30-minute job and phase limits. The
general CI also selects an exact-head full-game compile and offline baseline,
and the MCP workflow selects both Ubuntu and Windows protocol checks because
the shared persistence readers changed. Added test files currently select the
`tests/movement_save_chunks` suite; they do not by themselves select the
separate human-subtile or collector native suites. Other labels, changed paths,
manual options or a different base can change that result. This selection is
source analysis, not a claim that any hosted run occurred.

This tranche checks feasibility and the named synthetic case, not full-map
timing, live-Gaia restore or connected-player gameplay. It must not be executed
or published until Main reviews the source and separately obtains authorization.
