**Historical design record:** This describes the superseded exact-offset prototype at the stated baseline. Its zero-acceptance and no-native-test statements are historical, not the current tile-only implementation. See `docs/human-save-motion-candidate.md` for the current contract and dated evidence.

# Human detached-capture contract (proposal, disabled)

This is an offline design and executable model for review, not a production
implementation. The human movement guard remains in place. The model cannot
observe BYOND callbacks, native moves, hook yields or raw state writes and does
not demonstrate a safe save. Baseline: Civ13 master
`ec8725b6848ecddbf109ffdad9e7fc098c842ed2`, BYOND pin `516.1688`.

## Newer spatial-only candidate

The reviewer is assessing a smaller alternative to the whole-group design below:
capture only an identity-pinned turf and five numeric sub-tile fields between
pulses, then continue the ordinary yielding serializer. This preserves rolling
inventory semantics; it does not make inventory or the world an atomic snapshot.

The worktree has an operation-bound, nonyielding acknowledgement prototype in
`subtile_movement.dm`. It checks operation, actor, pulse and transaction identity,
rejects currently coupled/pulling bodies, and captures a detached position. The
movement worker calls it after updating `expected` or after releasing the old
transaction. An optional serializer path binds the captured request to an exact
frame and injects its detached capsule while retaining parent hooks. Operation
cleanup owns requests. A separately guarded experimental path has reference-first
roster routing, bounded waits, origin drain, late human lifecycle invalidation
and encoded-origin-edge inspection. Its initial bounded human-registry copy is
sealed at save admission, before save-work yields. Human creation, login or
destruction after sealing invalidates the candidate rather than stopping the
player. This is not yet a proof that every possible control handoff or transient
body is covered. No build defines that experimental flag and
the movement admission guard is unchanged. No native test validates the source,
compile, acknowledgement, field injection, parent hooks or timing.

The current candidate acceptance rate for a save with any captured human request
is **zero by construction**: operation-wide transient containment coverage is
not proven and its required flag remains false. Preliminary encoded geometry and
known-link checks can now set their own flags, including for a nonzero offset,
but have no native validation. This is a development hold, not usable behavior
or a measured population rate.
Pulling or coupled bodies are refused and handoff waits are bounded to 100
deciseconds; actual runtime rejection frequency is unmeasured. Crates,
barricades, televisions and modular vehicle frames have `CanPass` overrides
that cannot safely be inferred from density alone. Encoded inspection checks that
the human entry occurs once under the recorded turf and that present slot fields
refer to unique direct saved children. Missing slot fields and constructor effects
are not proven; neither check establishes footprint clearance or reciprocal
buckle/riding/control links beyond the audited named fields. Preliminary checks
now reject known reciprocal links and unsupported footprint types, but unknown
after-load behavior is not covered. The extra candidate scan can be expensive and has
not been measured on a representative world. Its caps cover shards, entries per
shard, content chunks and total edges, with a 120-second world-time deadline
checked between entries. These are logical bounds and do not preempt a native
savefile read.
The candidate marker also requires geometry, link and containment proof; the
containment flag remains false. It fails rather than substituting live-world clearance for saved
candidate clearance, weakening `after_load`, rounding offsets, or teleporting.

Before activation, the saver must prove that it expires requests and releases
every reference on success, exception, timeout and owner loss. An idle actor can only
acknowledge without a transaction or pulse. A late ack must not bind a later
operation. The serializer must bind the exact frozen turf and per-frame capsule,
inject the capsule even if the live field is null, suppress stale live capsule,
`step_x`, `step_y`, and transient glide values, preserve parent save hooks, and
never cancel the active movement transaction. Frozen-origin roster draining must
handle discoveries on either side of the coordinate frontier and references
before turf traversal. The active operation's load/recovery restrictions and
cross-level barriers remain separate. Candidate slot/containment validation must
detect inconsistencies rather than claim atomic inventory.

An offset capsule is only restorable if the saved anchor and surrounding turfs
remain passable and restored linkage remains compatible. For example a player
can walk away and a wall can later be built at the saved anchor, or the player
can become buckled after the anchor is captured. `human_subtile_destination_clear`
and `human_subtile_unlinked` are checked during `after_load`, after import has
begun; an incoherent candidate must not be marked complete merely because the
capsule was valid when first observed. A source-level way to validate the saved
candidate's actual future collision/link state is still required. The executable
spatial model shows these counterexamples; it does not establish DM behavior.

## Admission and capture

1. Capture a bounded, identity-pinned roster that covers every human which can
   acquire player control during the operation, including pending joins, reclaims,
   possessions and replacements. A roster scan of current clients alone is not
   sufficient. Missing, replaced, newly controlled or cross-level roots fail the
   candidate; no omitted player may quietly take the legacy moving path.
2. Establish an audited nonyielding closure of the human, owned descendants and
   referenced durable datums/lists. Prove actual hook implementations, including
   inherited and subtype overrides; reject unknown hooks, transfers, callbacks,
   external movers, cyclic containment, unsupported relationships and over-budget
   groups. The existing animal preflight intentionally rejects a second movable;
   its type check cannot simply be removed. Same-tick `sleep(0)` is not detected
   by a world-tick comparison, so a tick check alone is not hook evidence.
3. At a safe pulse boundary freeze the root's actual turf and sub-tile capsule,
   plus the full owned graph and item slot references, in a bounded no-yield
   typed stage. Keep the existing version-3 codec, identities, aliasing and
   durable bindings; validate slot targets against captured containment. Replay
   only detached bytes and defer the single spatial edge to the frozen turf.
   Identity, origin, group membership and per-level reference rules must be
   validated before the edge and before final candidate publication.
4. A fully detached and identity-pinned group may retain its snapshot after live
   movement or an item drop; a movement journal is not inherently required.
   A later serializer reference must not claim the same saved item for another
   owner. A proposed export-reference fence rejects a member already exported
   before group capture, pins group identities, skips later foreign spatial
   rediscovery, rejects foreign field references, and refuses capture by another
   group. All typed, list, level-link and owner paths plus deletion and identity
   reuse need coverage. This fence is not implemented. Preserve the existing
   cross-z and nullspace restrictions independently.
5. An incomplete group, unknown state, interrupted stage, ownership change during
   capture, ambiguous later reference or callback exception aborts the candidate
   and clears all transient stage/frame
   state. The completion marker must never describe that candidate; retain the
   previous completed generation and recovery evidence. Validate both the normal
   no-marker path and any failure while copying or invalidating the backup.

## Current experimental state

The later spatial-only candidate supersedes the group-wide reservation proposal
below. It seals the classified human roster and validates the encoded candidate's
unique saved parent, slots, known physical links and a narrow audited footprint.
It does not attempt to journal transient inventory history or promise an atomic
inventory. A new, deleted, reclassified or unsupported contained human refuses
the candidate. The branch is disabled in normal builds and has not been compiled
or run. An admitted ordinary or exact-owner restart save has an experimental
motion bypass; load, dimension and startup recovery holds remain. Restart notice,
post-save validation, intent publication and shutdown ownership are unchanged.
Its unowned pull-pair path
falls back to the existing ordinary drag path during an eligible save; a human
still pulling at capture or final validation is conservatively refused. Whether
these changes are safe in native gameplay remains unproved.

The Python model and source-text checks are not engine evidence. A full-source
writer/fresh-reader adapter and Linux driver are present but not compiled or run.
The following sections preserve the earlier design audit and are historical.

## Earlier implementation blockers

* Human `before_save` cancels an active sub-tile transaction and refuses an
  in-flight pulse. A capture-time handoff must avoid freezing or cancelling a
  player's ongoing action while also preserving truthful position and collision.
  `perform` waits between native pulses, `finish` calls `complete` and its
  movement-completion hooks, and `wait_paid_interval` may sleep. Capture must
  not call either finish or wait, or clear transaction/pulse pointers. A future
  between-pulses acknowledgement must preserve transaction identity, exactly-once
  completion and paid deadline, and prove no native pulse overlaps the stage.
  Pull-pair admission and coupled ownership have separate save guards.
* The current typed staging path and preflight only admit empty, unlinked animals.
  Allowing inventory requires group-wide reservations and unique containment;
  objects may have arbitrary subtype hooks and saved datum graphs. No blanket
  claim about their nonyielding behavior is justified.
* The current roster and join/control paths are not proven to cover every way a
  player can appear. The proposed reference fence is not wired into production;
  raw location writes make a movement-hook-only journal insufficient.
* Human slot/reference validation must operate on actual encoded candidate data,
  not only live state or this model. A marker must follow that validation and all
  relevant reference-fence checks. Preserve existing recovery and format contracts.

## Offline model and remaining acceptance

`human_contract_model.py` deliberately requires three unimplemented production
capabilities before admission. `test_human_contract_model.py` exercises detached
same-level walking, nested containment and slot references, missing capabilities,
in-flight/coupled roots, transfers, cross-level motion, partial capture failure,
roster loss and conflicting spatial owners. It models the contract only. It does
not run DM, test native savefile semantics or establish a real reference fence.
No movement guard or runtime behavior is changed.

## Source audit and current incremental code

The inherited `atom/movable/before_save_context` checks pull-pair checkpoints;
`atom/movable/before_save` can update corpse decay; the human override cancels
the active transaction and snapshots offsets. Human `get_saved_vars` calls the
generic variable walker and removes sifting fields. Typed graph recursion may
reach other datum and item overrides; auditing a few named human hooks is not a
closed-world proof. In particular, inspect inherited and indented subtype
definitions as well as slash-qualified declarations.

`equip_to_slot` uses `forceMove` and then changes slots and calls `equipped`,
while other inventory code writes `loc` directly, for example clipboard,
paper bundles, storage and clothing accessories. A journal only in `Move` or
`forceMove` is therefore incomplete. Slot writes, item creation, deletion,
cross-root links and control handoffs need actual source coverage or the proposed
reference fence, which must refuse ambiguous candidate relationships.

The existing exporter does not implement that fence. `BuildVarDirectory`
returns a previously saved ID even when referenced by another frame, and
`add_export_content` silently retains the first saved parent. If a captured bag
moves from player A to player B, B's later hand field can point to the saved bag
while its saved containment remains under A. A per-human pause alone does not
resolve this cross-group inconsistency. A yielding lease also has no demonstrated
upper bound: hooks, `save_work_check`, native savefile operations and large
graphs can delay release while damage and simulation continue. Shortening the
lock does not establish player safety; protecting every relevant hazard during
a lease needs a separately reviewed, complete interaction boundary.

`moving_human_ownership_preflight` in `saving.dm` is a disconnected, bounded
no-write group and slot inventory. It does not reserve serializer IDs, run hooks,
stage data, observe later changes, or authorize moving capture. Failures retain
no group fields; ignored, unsaved, oversized and unsupported containment is
conservatively refused. It is not called by the saver, and cannot make players
move during saving. This is one production-source building block, not a fix.

After the missing production pieces and source review, prepare an isolated native
fixture using the existing moving-save runner: interleave both sides of the scan
frontier, reference-first discovery, human pulses, nested bags and slot aliases;
cover transfer/delete/unknown-hook/cross-z/failed-stage controls, marker and
backup bytes, and a fresh-process restore. That native execution remains separately
held. Full-size timing and connected-client gameplay are distinct evidence.
