# Persistence handoff review revision 2

Review-only revision of the four P1 findings on `24cdf8c0c`. Production base is
still `4344a87d29f6d3b5736bc9ccb46d22030390948c`; no shared implementation,
adapter or ledger has landed. Serializer retains the shared persistence files.
PR3105 is experimental, not a baseline. The initial diff in
`extraction-persistence-hook-proposal.md` is superseded and must not be applied.
Local helpers, compilers, runtime, benchmarks and screen actions remain held.

## Pinned generation consumed by every reader

`acquire_restore(storage, captured_policy)` must obtain exclusive operation
ownership, select the exact generation allowed by the account-domain guard, and
return an immutable input set. The operation owns the canonical generation
directory, exact manifest bytes/digest, exact metadata bytes, dimensions/map ID,
expected level set and verified native save handles. Callers cannot supply
arbitrary paths or replace handles. Pinning must complete before ClearMap.

For opted-in restores, ALL readers use this set:

| Current reader | Proposed replacement |
| --- | --- |
| `validate_world_save()` completion/meta `fexists` and `file2text` | `operation.manifest_bytes` and `operation.metadata_bytes`, already verified and pinned; no mutable completion-marker reread. |
| Validation `new("map_saves/[z].sav")` | `verified_level(operation, captured_policy, z)` returning the captured handle, with checked ownership and content identity. |
| Initial Load_World turf-allocation level open | Same verified handle accessor, resetting its directory explicitly. |
| Per-level recursive restoration open | Same verified handle accessor; recursive calls receive that exact handle and operation. |
| `load_map_metadata()` `file2text("map_saves/map.txt")` | Parse the same `operation.metadata_bytes` validated before mutation. |
| Recursive `Load_Entry` / typed decoder | `require(operation, captured_policy, "restore", handle)` checks that the handle belongs to the captured set; no new open or ambient-token fallback. |

Ordinary null-policy calls retain their existing paths and legacy-v2 validation.
Null policy is captured explicitly: changing it to a policy, or removing/replacing
an opted-in policy, invalidates the operation rather than skipping checks.

Save publication writes a new private generation directory, never overwrites a
published generation and copies only its manifest-declared file set to backups.
After metadata and ALL native level handles are flushed/closed, exact byte hashes
are verified and an immutable manifest is published, followed by its digest-bound
completion marker. A mutable selector points only to that completed identity;
it is not authoritative over the independent account-domain guard. Acquisition
pins one selector result and never follows it again during a yielded operation.

The publication boundary assumes exclusive host ownership of the generation
directories. The in-process token is not an OS lock. An external writer, missing
file, changed byte hash or mutable/unverifiable handle blocks acquisition or
invalidates the operation before admission. The serializer must verify a pinned
BYOND516.1681 binary digest and immutable-handle/private-snapshot strategy; no
claim is made that a normal savefile handle makes a writable path immutable.
If verified pinning cannot be supplied, shared restore implementation stays
blocked. A post-load checksum alone cannot repair pre-mutation pinning.

## Checked callbacks and exception-safe ownership

Every callback either throws or returns the exact documented result. No caller
may ignore FALSE/null or treat a logged error as success:

| Callback | Checked result |
| --- | --- |
| `begin_save` / `acquire_restore` | Non-null exclusive operation with captured policy/storage identity, kind and mutation epoch, or throw. Failed acquisition unwinds its own partial ownership. |
| `require` | Exactly TRUE or throw. Compares live policy identity with captured identity even when either is null; validates handle membership when supplied. |
| `level_closed` | Exactly TRUE or throw; rejects duplicate/missing/out-of-range level completion. |
| `publish_generation` | Non-null immutable committed-generation proof matching operation, manifest digest and exact file set, or throw. Caller verifies proof through `accept_committed`, which must return TRUE or throw. |
| `refresh_restored` | Exactly TRUE or throw after identity and constructor-ledger reindexing; no duplicate/missing registration can be ignored. |
| `finish_restore` | Non-null complete proof bound to the same operation, pinned manifest and current ledger epoch; `accept_restored` must return TRUE or throw. |
| `end_operation` | Exactly TRUE or throw; idempotent same-operation cleanup, with failed outcome retaining the durable recovery block. |

The entire acquire/preflight/validate/mutate/metadata/finalize sequence is inside
one exception scope. Capture policy once before acquisition. On any exception,
record that original exception, attempt cleanup in a nested exception scope,
record any cleanup error separately, then clear wrapper overlap state regardless
of cleanup outcome. Cleanup failure cannot replace the original error, publish
success or erase durable recovery state. If cleanup alone fails after otherwise
successful work, report failure and retain recovery block. The policy keeps
failed transient ownership non-admissible until explicit recovery, while the
wrapper Boolean is always cleared. No early return may bypass cleanup.

The proposed common guard is owned by the serializer:

```dm
/map_storage/proc/persistence_require(datum/persistence_operation/operation, datum/persistence_policy/captured_policy, kind, savefile/handle)
    if (world_persistence_policy != captured_policy)
        throw EXCEPTION("Persistence policy identity changed")
    if (!captured_policy)
        if (operation) throw EXCEPTION("Operation supplied without policy")
        return TRUE
    if (captured_policy.require(operation, src, kind, handle) != TRUE)
        throw EXCEPTION("Persistence operation rejected")
    return TRUE
```

This is review code, not an existing proc. Always call the guard directly; never
wrap it in `if (world_persistence_policy)`, which would skip checks after removal.

## Exact token propagation replacements

The following replacement catalog names exact original expressions in the frozen
source. The serializer must produce and review a full unified patch from it
before shared implementation. It is not a claim that the initial small diff
covers these paths. Trailing named arguments preserve ordinary fixture positions.

| Original | Proposed replacement |
| --- | --- |
| `Load_World()` declaration | `Load_World(operation, captured_policy)`; guard first, use verified-level accessor at BOTH level-open sites. |
| `validate_world_save()` declaration | `validate_world_save(operation, captured_policy)`; guard first, use pinned metadata/manifest/levels under policy. |
| `load_map_metadata()` declaration | `load_map_metadata(operation, captured_policy)`; guard first, use pinned metadata under policy, checked TRUE result. |
| `ClearMap()` declaration | `ClearMap(operation, captured_policy)`; guard before and after EACH sleep, before EACH qdel and after its callbacks. |
| `Save_World()` declaration | `Save_World(operation, captured_policy)`; guard first, stage private generation files; checked closure/publication proof. |
| `Load_Entry(..., var/lag_fix = 0)` declaration | Append `operation, captured_policy`; guard before first TICK_CHECK and immediately after it. |
| `Load_Entry(savefile, x, null, object, nocontents = nextContents, lag_fix = lag_fix)` | Append `operation = operation, captured_policy = captured_policy`. |
| `Load_Entry(savefile, y, lag_fix = lag_fix)` | Append the same two named arguments. |
| `Load_Entry(savefile, x, nocontents = nextContents, lag_fix = lag_fix)` | Append the same two named arguments. |
| `Load_Entry(savefile, turf_ref, old_turf)` in Load_World | Append the same two named arguments. |
| `decode_saved_value(savefile, savefile[v])` | Append `operation, captured_policy`. |
| `decode_saved_value(savefile/F, list/value)` declaration | Append `operation, captured_policy`; guard at entry with handle F. |
| `Load_Entry(F, value["ref"])` in typed decoder | Append the two named arguments. |
| `decode_saved_value(F, encoded_key)` / `(F, encoded_value)` | Append `operation, captured_policy` to BOTH recursive calls. |

Exact mutation-context additions in Load_Entry:

```diff
@@ cache-reference branch
    if(starting_loc)
        var/atom/movable/A = existing_references["[ind]"]
+       persistence_require(operation, captured_policy, "restore", savefile)
        A.loc = starting_loc
+       persistence_require(operation, captured_policy, "restore", savefile)
@@ lag-fix branch
        if(so_far > per_pause)
            sleep(10)
+           persistence_require(operation, captured_policy, "restore", savefile)
            so_far = 0
@@ native replacement
+   persistence_require(operation, captured_policy, "restore", savefile)
    if(old_turf)
        var/xa = old_turf.x
        var/ya = old_turf.y
        var/za = old_turf.z
        old_turf.ChangeTurf(type, FALSE, FALSE)
+       persistence_require(operation, captured_policy, "restore", savefile)
        object = locate(xa,ya,za)
    else if(replacement)
        object = replacement
    else
-       object = new type(starting_loc)
+       object = persistence_construct(operation, captured_policy, type, starting_loc)
+   persistence_require(operation, captured_policy, "restore", savefile)
@@ every saved variable iteration
    for(var/v in savefile.dir)
+       persistence_require(operation, captured_policy, "restore", savefile)
        savefile.cd = entry_path(savefile, ind)
@@ nested native content removal
        if(ob.loc == container)
+           persistence_require(operation, captured_policy, "restore", savefile)
            qdel(ob)
+           persistence_require(operation, captured_policy, "restore", savefile)
@@ variable-iteration yield
        savefile.cd = entry_path(savefile, ind)
        TICK_CHECK
+       persistence_require(operation, captured_policy, "restore", savefile)
```

These are context fragments, not standalone applyable hunks. Before each
`object.vars[v] = ...` assignment, the current guard must still match the same
handle and policy; recursive decode may yield, so guard AGAIN after decoding and
before assignment. The final human rejuvenate/name restoration is authorized
restore mutation with checks before/after callbacks. Before the initial
Load_World `T.ChangeTurf(type, FALSE, FALSE)` add a guard, then recheck after it
and after EVERY TICK_CHECK. Apply the same after-yield check during recursive
value iteration and before a cached-object/cached-list return. Before/after each
after_load callback, guard; then check `refresh_restored == TRUE`, or throw.
Final metadata and finish_restore run under the same captured policy/operation.

`persistence_construct` must establish a synchronous constructor context for
the explicit operation, register the returned object and constructor children,
and clear that context on constructor success or exception. It cannot grant
unrelated callbacks authority merely because an operation is globally active.
Callbacks scheduled by constructors need an explicit operation-bound capability,
must recheck before execution and be joined/drained or cancelled before finalize.
Unattributed/asynchronous creation invalidates coverage and blocks completion.

## Concrete mutation inventory and disposition

This inventory is scoped to paths read in the current extraction checkout; it is
not exhaustive proof that every subtype participates. Missing or bypassing paths
are an explicit implementation blocker, not permission to set a complete flag.

| Actual source/entry point | During an operation |
| --- | --- |
| `code/game/objects/items.dm` New/Destroy, proposed Del hook | Register under explicit constructor capability; unrelated construction invalidates epoch. Lifecycle callbacks are idempotent and validate authorized restore/retirement deletion. |
| `code/processes/abandoned_items.dm` item Move/forceMove/check_abandonment | Reject ordinary movement before side effect; defer decay sweep without changing durable age. Authorized restore movement requires explicit capability. |
| `code/game/objects/items.dm` attack_hand/attackby | Reject acquisition/item mutation before claim or attack. |
| `code/game/objects/items/weapons/storage/storage.dm` insertion/removal eligibility and native contents writes | Reject ordinary direct-loc custody; restore contents requires same operation capability and before/after callback checks. |
| `code/game/mob/inventory.dm`, human `human.dm` hand placement and human `inventory.dm` quick equip/drop | Reject ordinary equip/drop/put-in-hands before direct location assignment. |
| `code/modules/1713/animal_harvest.dm` harvest_animal/harvest_products/harvest_food | Reject new harvest; resumed waits recheck before costs/yields/qdel. No queued automatic harvest replay. |
| `extraction/workshop_components.dm`, `private_car_workshop.dm`, `vehicle_purchase.dm`, `vehicle_transfer.dm`, `vehicle_cargo.dm` | Reject new crafting/purchase/transfer; resumed paid actions recheck reservations before consumption or issuance. |
| `extraction/native_market.dm`, `transactions.dm`, `settlement.dm`, `ipc_economy.dm` | Reject trade/account mutations before journal intent; recovery uses explicit journal capability, not implicit restore privilege. |
| `extraction/account_store.dm` commit_profile and account admission | Reject unrelated writes/decode; only operation-bound guard/release CAS allowed. Existing read leases still apply. |
| `extraction/surface_loot.dm` claim/materialize/forfeit, `equipment.dm` decode, home retirement | Reject ordinary issuance/claims during fence; exact authorized retirement and restore paths check before/after callbacks. |

Native turf constructors, scheduler callbacks and subtypes bypassing Move/New
also require review. A base item hook alone is insufficient. No generic global
construction hook or broad runtime world scan is authorized by this proposal.

## Extraction-owned durable anti-rollback and release journal

Extraction owns a separate account-store journal rooted at
`[accounts.store.root]_world_handoff/`, outside `map_saves`, generation directories
and `map_backups`. Its record uses the account-store revision/intent/snapshot
protocol and must never be copied or restored with a world save. Initial missing
records are not inferred from a world marker. Existing account-directory/auxiliary
census must validate this explicit domain before admitting it; never blindly
skip an unknown directory. External writers still require exclusive host ownership.

Proposed exact extra-field schema inside the existing store envelope:

```text
world_handoff = {
  schema: 1,
  map_id: exact map ID,
  dimensions: [maxx, maxy, maxz],
  selected_generation: 64-character manifest digest or null before first commit,
  selected_operation: 64-character operation ID or null,
  operations: { operation_id: {
    owner: canonical account owner,
    phase: prepared | runtime_retired | generation_committed | release_pending | released,
    account_before_revision: exact integer,
    account_before_digest: 64-character digest,
    binding: exact existing eight-field home_replica binding,
    root_graphs: { root_id: exact graph digest },
    root_nodes: exact unique persistent-ID set,
    generation_digest: null or exact manifest digest,
    account_after_revision: null or exact committed revision,
    account_after_digest: null or exact committed profile digest,
    marker_after_digest: null or exact acknowledged marker-state digest
  } }
}
```

Reject extra/missing fields, duplicate/invalid IDs, mismatched map/dimensions,
invalid phases and noncanonical hashes. Journal revision belongs to the existing
store envelope, not a second independent counter. Bound operations/root sets
explicitly; capacity exhaustion blocks new handoffs without dropping terminal
records or weakening anti-rollback. Exact capacities and supported hash primitive
remain serializer/extraction review decisions; they cannot be silently invented
as an entitlement limit. Operation ID binds a unique request plus exact owner,
before-account revision/digest and binding; replay requires identical content.

Each transition CAS-checks the loaded journal revision AND exact previous
operation phase/content, committing through the existing intent/snapshot path.
Account release separately CAS-checks its expected revision/digest. A stale,
pending, missing, conflicting or unreadable guard blocks restore, release and
decode. Its backup policy accepts only the exact selected generation digest and
operation with matching immutable files. An older structurally valid or correctly
hashed backup rejects. No timestamp ordering or greatest filename selection.
Advancing the selected generation requires a new reviewed CAS transition proving
all retained ownership obligations; ordinary saves cannot advance it implicitly.

The generation manifest binds the operation ID, before-account digest/revision,
binding digest and exact root/node exclusion proof. Before generation_committed,
inspect the COMMITTED pinned save bytes' entry/contents/reference graph, not just
the live ledger: retired roots and nested nodes must be absent as physical saved
entities. The verified complete constructor census must agree. A graph digest
or empty runtime location alone cannot establish exclusion from serialized bytes.

Release ordering and recovery:

1. Commit prepared guard before physical retirement; original home receipt and
   binding remain reserved. CAS runtime_retired after actual removal.
2. Publish immutable save generation under the fence. Verify committed bytes and
   full ledger proof; CAS generation_committed/select its exact digest.
3. CAS release_pending before changing either account or marker. Record the exact
   intended after-account revision/digest; compute the full proposed profile first.
4. CAS account transition, then acknowledge exact marker transition under the
   same fence. A partial transition keeps release_pending and blocks decode.
5. Verify durable account revision/digest plus acknowledged marker state, then
   CAS released. Retain the guard permanently across both releases and restarts.
   Decode still requires this guard and a verified matching restore/census proof.

Crash after save publication but before guard CAS leaves an unselected orphan
generation: keep bound and recover explicitly, never auto-admit it. Crash after
guard selection but before account release keeps bound. Crash after account
commit or marker transition remains release_pending; recover only by comparing
actual committed account and marker state with the recorded intended values.
No account rollback/refund or replacement root is inferred. If exact matching
recovery cannot complete, leave recovery-blocked. Missing/conflicting guard after
either release never makes an unbound account admissible. Released guard replay
also checks current account revision/digest: later account changes require a new
reviewed generation transition, not reuse of stale release proof.

## What still blocks a full exact patch

This revision resolves the required ownership and state semantics but is not
shared-implementation ready. The serializer must approve/implement immutable
native input pinning and byte hashing, exact callback types and exception cleanup.
Extraction must finish the enumerated subtype/direct-custody/asynchronous audit
and bounded ledger/CAS-domain policy before an exhaustive callback patch can be
claimed. The context catalog above explicitly replaces the insufficient initial
hunks; it is not a complete applyable token-propagation patch. An exhaustive
unified diff remains required by review. No source scaffold, release bypass or
runtime acceptance has been added to hide these blocking contracts.
