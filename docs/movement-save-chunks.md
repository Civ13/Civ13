# Bounded moving-root save chunks - proposed first cohort

Status: isolated implementation draft; no native run, publication, or deployment.
Base: ef3faa6b90.

## Scope and stopping rule

Implement and review a real production path for bounded empty direct-turf simple-animal roots,
with deterministic interleaving tests and a prepared native fixture; do not
activate, save, restart, or deploy on a live server. Preserve current failures
until the replacement path establishes its stated invariants.

## Semantics

This remains an incremental world save, not a single-tick world snapshot.
The implemented first cohort is simple animals with empty contents and no
corpse, pull, buckle, ride/control or grab/pin coupling. Humans and owned inventory
groups are not admitted to the new capture path. Each admitted mobile root has
one frozen origin turf and one detached record group. Different roots may have different capture times. The current root group includes only the empty animal and its eligible saved
scalar/datum/list state. Contained inventory and human slot fields are future
cohorts, not implemented coverage. Capture must not publish mixed ownership. General cross-root
transfers, deletion of an uncaptured member, and unsupported hook behavior remain
fail-closed in this first cohort; ordinary walking is not a reason to retry.

## Proposed production seams

1. At admitted save preparation, reserve a bounded copy of the existing mob_list
   registry. Record identity independently of turf traversal. Leave over-budget
   registries on the legacy path before changing generation files. Pinning does not prevent native del;
   a missing admitted identity is a refusal, never silently omitted.
2. Leave non-cohort roots on the existing serializer. Defer direct-turf mob roots
   to a save-local queue, retaining first identity and origin policy. Deduplicate
   saved-variable discovery and spatial discovery against the same entry table.
3. Stage each queued root using the existing typed encoder and an in-memory
   savefile sink. Reserve node/list/edge work before expansion. During this small
   staging section, save_work_check checks budgets instead of yielding; explicit
   TICK_CHECK sites must use the same typed staging-aware policy. Never globally
   disable tick checks. Check world.time and elapsed/tick budget around callbacks
   and native operations. A tick-changing hook invalidates the stage. Same-tick sleep(0) cannot be
   detected by this check; current admitted hooks must remain audited nonyielding. Hooks retain
   their existing gameplay semantics; a failed hook is not assumed rolled back.
4. Only a completed group escapes the capture section. Copy its detached typed
   records with normal yields; do not reread live fields, contents, or location.
   Preserve existing entry/list IDs, aliases, durable bindings and level links.
   A stage cannot share partially written IDs with an abandoned attempt.
5. After the coordinate scan, append the root ref to its frozen turf record.
   Validate exactly one spatial owner, reference closure, and saved human slot
   references against saved containment before allowing the generation marker.
6. Retry only explicitly transient admission cases, with attempt/work/time bounds.
   Reuse completed groups within this generation; never reuse across generations
   without authoritative dirty tracking. A failed stage must undo every staged
   entry/list/binding reservation or fail the whole candidate, not return a ref
   to incomplete output. The first implementation may refuse the candidate when
   rollback cannot be proven instead of pretending to support a deferred retry.

## Implemented limits and conservative refusals

If the global mob registry exceeds 8192 entries, the attempt retains the legacy
path rather than adding a new global save refusal. Eligible smaller registries
receive a bounded per-root no-write saved-field closure preflight; unsupported
external mover references and oversized graphs stay on the legacy path before
any serializer IDs are allocated. The roster cap is 8192 mobs. Each root allows 128 datum/list nodes, 2048 list
edges, 64 encoder nesting levels, 8192 checks, and 1 MiB logical reservations.
Capture refuses after 10 percentage points of tick use, at 90% total tick use,
a tick change, or more than one decisecond elapsed. These checks do not preempt
one native operation and are not a hard latency or resident-memory guarantee.

A failed chunk aborts the entire candidate. There is intentionally no retry of
partially allocated entry IDs, lists, durable bindings, or level links. Completed
records are reused within the attempt. The current code does not implement a
second-pass retry budget; the queue handles undiscovered admitted roots, not
unstable ownership groups. New native fixture source is prepared only.

## Required review decisions / dependencies

- In-memory savefile copying must preserve native typed values and existing
  version-3 layout without unsafe text import or live reserialization.
- Shared durable graph and cross-level link reservations currently bind during
  recursive traversal. Stage isolation must own these too; file isolation alone
  is insufficient. No chunk retry is safe until reservation rollback is proven.
- mob_list covers mobs, not all moving objects. Moving item/container discovery
  requires its own authoritative registry/journal before expanding the claim.
- A callback/native operation is nonpreemptible. Logical limits and post-operation
  budget refusal are not a hard latency bound. Reject unaudited yield-capable
  cohort hooks rather than claiming a global maximum pause.
- Existing map_backups completion-marker protocol remains the recovery boundary.
  This proposal does not establish crash-atomic filesystem rename/durability.

## Planned broader regression matrix (not all implemented)

Positive: root oscillates across scanned/unscanned turf boundaries at each writer
yield; two roots swap; field discovery precedes spatial discovery; stable nested
bag and player hand slots preserve aliases and exactly-one containment; completed
chunks are reused rather than recaptured.

Refusal: nested item transfer, cross-root slot conflict, root/child deletion,
replaced turf, paid-hook invalidation, yielding callback, over-budget graph,
retry exhaustion, and abandoned-stage ref reuse. Every refusal retains a readable
prior completed generation and emits no new completion marker.

Differential omission controls must remove roster discovery, owner uniqueness,
slot containment, tick-boundary refusal, and abandoned-stage cleanup separately;
each must reach its named assertion, not merely fail compilation or time out.

Offline models are algorithm evidence only. Native compilation, disk-backed
roundtrip, interruption recovery and representative timing need separate exact-
head results. No local/native/live run is authorized by this design document.

## Births and capture timing

Only animals admitted from the copied initial registry use this new path. Later
births remain on ordinary incremental turf traversal; no new guarantee of their
inclusion is claimed. Each staged animal has a per-root capture time, while the
rest of the world retains existing per-field/incremental timing. This is not a
global atomic snapshot. The current offline tests and prepared native scenarios
are enumerated in tests/movement_save_chunks/README.md; the matrix above also
lists future inventory/deferred-retry acceptance work.

## Memory acceptance is required

See tests/movement_save_chunks/memory-benchmark.md for the proposed isolated
RSS/private-bytes, tick/heartbeat and repeated cleanup matrix. Native staging
overhead, source pins, path copies and allocator retention are outside the
1 MiB logical reservation. No memory benchmark has run; the logical bound is
not a measured heap cap and is not sufficient deployment evidence.

## List identity cache optimization

Native bounded measurements identified `"\ref[L]"` formation as a population-
dependent spike inside capture. The serializer now keys its temporary list-ID
cache directly by the pinned list. This affects legacy and chunked serialization,
not only animals. Numeric list IDs, typed envelopes, pin-identity checks, insertion
before recursive encoding, per-level resets and final cleanup are unchanged.
Native primitive tests compare the old/new registration behavior, including fresh
`filters` getter handles; fresh-process typed-codec tests and the full old-key
baseline/direct-key candidate matrix must still pass on the final head. No capture
limit is raised and a failed chunk still aborts the entire candidate.
