# Persistence handoff hook proposal

Review input only, based on extraction production source at
`4344a87d29f6d3b5736bc9ccb46d22030390948c`. Documentation descendants do not
change that source. These hooks are not applied or implemented. Serializer owns
`code/modules/persistence/{functions,saving,loading}.dm`; extraction owns the
adapter, receipts, opt-in ledger and tests. Serializer PR3105 at
`ee3746b60d6cb561fa4fcd4e89b69eefa9af1cdd` is experimental and is not the base
or an accepted generation API. Shared implementation requires exact-diff review
and coordinator scope release. All local execution remains held.

The minimal shared entry-point changes below specify token propagation, explicit
file closure and callback locations. The serializer must supply the policy and
operation types before any patch is applied. These are exact replacement hunks,
with source context, rather than a working implementation of the policy. Tabs in the diff block are encoded as literal \t for Markdown; decode them before a whitespace-aware applicability check against the CRLF checkout.

```diff
diff --git a/code/modules/persistence/saving.dm b/code/modules/persistence/saving.dm
--- a/code/modules/persistence/saving.dm
+++ b/code/modules/persistence/saving.dm
@@ -9,2 +9,3 @@
-/map_storage/proc/Save_World()
+/map_storage/proc/Save_World(datum/persistence_operation/operation)
+\tif (world_persistence_policy) world_persistence_policy.require(operation, src, "save")
 \tclear_bookkeeping()
@@ -59,7 +60,13 @@
 \t\t\t\tTICK_CHECK
+\t\tif (world_persistence_policy) world_persistence_policy.require(operation, src, "save")
+\t\tsavefile.Flush()
+\t\tsavefile = null
+\t\tif (world_persistence_policy) world_persistence_policy.level_closed(operation, A)
 \t\tlog_startup_progress("\tSaved z-level [A].")
 \tclear_bookkeeping()
-\tif(!text2file(time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)"),"map_saves/save_complete.txt"))
+\tif (world_persistence_policy)
+\t\tworld_persistence_policy.publish_generation(operation, src)
+\telse if(!text2file(time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)"),"map_saves/save_complete.txt"))
 \t\tthrow EXCEPTION("Could not write save completion marker")
 \tlog_startup_progress("Finished saving.")
 \treturn 1
diff --git a/code/modules/persistence/functions.dm b/code/modules/persistence/functions.dm
--- a/code/modules/persistence/functions.dm
+++ b/code/modules/persistence/functions.dm
@@ -172,3 +172,5 @@
-/map_storage/proc/ClearMap()
+/map_storage/proc/ClearMap(datum/persistence_operation/operation)
+\tif (world_persistence_policy) world_persistence_policy.require(operation, src, "restore")
 \tsleep(1)
+\tif (world_persistence_policy) world_persistence_policy.require(operation, src, "restore")
 \tworld.log << "Clearing mobs..."
@@ -178,2 +180,3 @@
 \tsleep(1)
+\tif (world_persistence_policy) world_persistence_policy.require(operation, src, "restore")
 \tworld.log << "Clearing objects..."
diff --git a/code/modules/persistence/loading.dm b/code/modules/persistence/loading.dm
--- a/code/modules/persistence/loading.dm
+++ b/code/modules/persistence/loading.dm
@@ -153,2 +153,3 @@
-/map_storage/proc/Load_World()
+/map_storage/proc/Load_World(datum/persistence_operation/operation)
+\tif (world_persistence_policy) world_persistence_policy.require(operation, src, "restore")
 \tvar/datum/extraction_surface_service/surface_inventory
@@ -199,5 +200,7 @@
 \t\t\tfor(var/i in 1 to all_loaded.len)
 \t\t\t\tvar/datum/ob = all_loaded[i]
 \t\t\t\tif (ob)
+\t\t\t\t\tif (world_persistence_policy) world_persistence_policy.require(operation, src, "restore")
 \t\t\t\t\tob.after_load()
+\t\t\t\t\tif (world_persistence_policy) world_persistence_policy.refresh_restored(operation, ob)
 \t\t\t\tif(istype(ob, /obj))
```

The Save_World hunk replaces timestamp publication only for an opted-in policy.
It is not sufficient by itself: publication must also replace the existing backup
loop with manifest-directed exact-file copying and marker-last publication.
The current level `Flush()` API and binary digest primitive require verification
against pinned BYOND516.1681 before implementation acceptance. Text conversion of
binary saves, semantic equipment hashes and timestamps cannot substitute for
the exact closed-file byte digest.

## Wrapper and nested-call contract

`savemap()` must create an operation inside its existing exception scope, pass
it to `Save_World(operation)`, and release transient ownership on both success
and failure. The completion path may publish only after every expected level
is closed and metadata is finalized. Failure invalidates candidate completion,
leaves the previously committed generation intact where possible and retains
the extraction recovery block. Direct Save_World calls without a matching token
reject when the policy is opted in.

`loadmap()` must acquire the restore operation and validate generation content
and retirement policy before `ClearMap(operation)`. Its existing structural
validation is additional preflight. Pass the same operation to Load_World, keep
it through load_map_metadata and all after_load callbacks, and finalize ledger
coverage before releasing it. A failed preflight leaves the world untouched;
failure after mutation requires recovery and cannot report a complete census.
The direct ClearMap/Load_World paths must reject a missing token. Legacy ordinary
maps use a null policy and retain current validation and reads.

The serializer must additionally thread the operation through recursive
`Load_Entry()` and `decode_saved_value()` calls, validating immediately before
construction, direct location/variable restoration and after yielded waits.
Do not accept an ambient global token as authority for an unrelated direct entry
load. The new trailing argument must preserve existing fixture call positions;
ordinary null-policy entry fixtures retain their current behavior. The three
entry-point hunks above are review anchors, not a complete fence implementation.

The existing same-tick surface barrier must not simply be removed. The extraction
adapter will instead bind its bounded feed and graph rechecks to the verified
operation identity/epoch and full constructor ledger. Until that adapter and
ledger are implemented and accepted, `current_world_complete` stays false.

## Proposed adapter signatures

| Signature | Result and ownership |
| --- | --- |
| `begin_save(storage, context)` | Exclusive operation handle bound to exact storage/map, dimensions, owner retirement set and mutation epoch; rejects overlap. |
| `acquire_restore(storage, manifest, retirement_policy)` | Operation handle only after file set/hash and durable anti-rollback validation, before any world mutation. |
| `require(operation, storage, kind)` | Throws on absent, foreign, released or invalidated handle, wrong map/dimensions or unauthorized mutation. Never creates a token implicitly. |
| `level_closed(operation, z)` | Records each expected closed level exactly once; does not publish completion. |
| `publish_generation(operation, storage)` | Verifies all closed files and fence, commits immutable manifest then digest-bound marker; returns exact committed generation identity. |
| `register_item(item, constructor_context)` | Registers object identity before DMM census finalization without minting item IDs or permitting admission. Constructor-created children are independent registrations. |
| `unregister_item(item)` | Idempotent lifecycle removal for Destroy/Del; a missed or foreign event invalidates coverage. |
| `refresh_restored(operation, datum)` | Reindexes restored item IDs and nested membership after load callbacks; rejects duplicates, invalid IDs or unregistered construction. |
| `finish_restore(operation)` | Verifies manifest, mutation epoch, all levels, callbacks, metadata and bounded complete ledger feed; returns proof, never releases account/marker by itself. |
| `end_operation(operation, outcome)` | Releases transient ownership once; failure retains durable recovery/admission block. Runtime handles never enter native saves. |

These signatures are proposed review contracts, not checkout APIs. The
serializer decides the exact names/types and generic implementation; extraction
supplies retirement-policy data and ledger adapters without coupling the generic
save format to gameplay-specific journals.

## Ledger bootstrap and mutation coverage

The proposed bootstrap callback is the first action in
`/datum/global_init/New()`, before DMM construction. Opt-in selection must be
available before `map` exists; choose it explicitly from the compiled map policy,
not a later map-metadata constructor. Ordinary Nomads must keep a null policy.
`world/New()` and asynchronous controller setup cannot reset pre-map registrations
or declare startup/load coverage complete prematurely.

Proposed item callbacks register in `/obj/item/New()`, unregister idempotently in
both Destroy and Del, and refresh after saved identity assignment and after_load.
Exact hook placement requires an audit of relevant subtype parent calls. A type
that bypasses its parent constructor must have an explicit opt-in callback or
invalidate coverage. A bounded ledger overflow, missed registration, duplicate
identity or unexpected constructor during a fence blocks completion; it cannot
drop entries and retain a success flag. Persistent IDs alone do not cover newly
constructed items whose IDs are assigned later.

Acquisition, movement/direct-loc custody, harvesting, crafting, trade, account
writes and decay must consult the operation fence or invalidate its epoch before
side effects. Load-origin construction and custody changes require explicit
restore authority. The wrapper flag does not stop these actions. This review
must enumerate the actual opt-in entry points before shared hooks are activated;
adding the callbacks above alone is not authoritative mutation coverage.

## Durable release states and failure handling

| State | Durable evidence | Admission and recovery |
| --- | --- | --- |
| Bound | Existing account and marker binding agree. | Account decode remains blocked. |
| Prepared | Current retirement receipt binds account digest, owner, roots and placement. | Physical roots still reserved; replay cannot replace runtime refs. |
| Runtime retired | Existing same-process retirement receipt. | Still bound; neither restart nor missing roots proves a saved retirement. |
| Generation committed | Manifest binds exact closed files, retirement operation and root exclusion under a valid fence. | Still bound until generation and ledger proof validate together. |
| Release pending | Durable operation record binds committed generation, expected account revision/digest and marker binding. | All partial account/marker writes remain recovery-blocked. |
| Released | Account and marker transition acknowledged against the same operation, with durable anti-rollback guard retained. | Decode allowed only after complete proof; stale/unbound restores reject before mutation. |
| Ambiguous/failed | Missing files, invalid fence, mismatched receipt, partial write or incomplete coverage. | Keep or restore recovery block; no replay minting, automatic refund or inferred release. |

The serializer must choose the anti-rollback record's durable location and
generation/backup-selection policy. A record stored solely inside the selected
world save rolls back with that save and is insufficient. A conflicting or
unavailable authoritative record blocks extraction restore. Hashes do not prove
freshness. Release across the world files, account journal and marker is not an
atomic transaction; the explicit release-pending barrier and restart policy must
be reviewed before final unbinding is implemented.

Required future controls include missing/mixed/extra levels, mutation between
hashing and publication, failed manifest/marker writes, old valid backups,
release interruption at each store boundary, lost/foreign tokens after a yield,
constructors omitting parent calls, late/restored ID assignment, missed deletion,
ledger overflow, genuine fresh-DMM coverage and ordinary legacy-v2 positive
round trips. None ran for this proposal. Source review is not pinned compiler,
binary hashing, crash safety, native gameplay or complete-world acceptance.
