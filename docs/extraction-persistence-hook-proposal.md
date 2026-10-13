# Persistence handoff hook proposal

Review input only, based on extraction production source at
`4344a87d29f6d3b5736bc9ccb46d22030390948c`. Documentation descendants do not
change that source. These hooks are not applied or implemented. Serializer owns
`code/modules/persistence/{functions,saving,loading}.dm`; extraction owns the
adapter, receipts, opt-in ledger and tests. Serializer PR3105 at
`ee3746b60d6cb561fa4fcd4e89b69eefa9af1cdd` is experimental and is not the base
or an accepted generation API. Shared implementation requires exact-diff review
and coordinator scope release. All local execution remains held.

The initial entry-point diff below is superseded by the revised contract in
`extraction-persistence-review-v2.md`. It is retained as review history and must
not be applied: it reopened mutable paths, ignored callback results and lacked
complete token propagation. The revised contract is still review-only.

The initial shared entry-point changes below specify token propagation, explicit
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

## Concrete restore call-site and abort ledger

The scoped wrapper slice described below now addresses the ignored metadata
return and introduces typed runtime policy/attempt boundaries. The reader/token
interfaces in this ledger remain proposals, including propagation through ClearMap
and loading recursion. This distinction is source status, not runtime acceptance.

Source-only supplement checked at `d3e7aa61934b03388f56ee51d35b2e6ae9d7532e`.
This locates the previously proposed trailing-token changes; none are implemented.
The immutable-reader ABI and durable quarantine publication primitive are still
unavailable as verified checkout interfaces. Preserve the null-policy ordinary-map
path while requiring the following explicit boundaries for an opted-in policy.

| Current entry/call site | Required proposed interface and acceptance condition | Failure owner |
| --- | --- | --- |
| `functions.dm::loadmap`, before `validate_world_save()` and `ClearMap()` | Acquire typed restore operation before any mutation, bind selected generation/readers/pins/custody epoch, and perform structural validation using those same readers. Admission must be reserved during preflight. | Serializer wrapper releases transient resources on pre-mutation rejection; original live world remains untouched. |
| `loading.dm::validate_world_save` opens each pathname; Load_World opens it again for allocation and again for restoration | Pass explicit operation and selected reader membership through all phases. Pre/post pathname hashes alone cannot close replacement/ABA. | Reader/host owner must provide verified immutability or keep extraction restore blocked. |
| `functions.dm::ClearMap` sleeps before mob and object qdel passes | Pass operation; check custody after each sleep, before each disposal and after callbacks. | Serializer abort owner records mutation-started status before first effect; physical owner classifies disposal continuations. |
| `loading.dm::Load_Entry` recursive calls at contents, reference and legacy-list restoration; typed field call into decode_saved_value | Add trailing operation without shifting existing positional/optional arguments; every recursion retains reader membership and cache ownership. Direct opted-in calls without an operation reject. | Serializer; caches and partially constructed objects cannot be returned as complete on token loss. |
| `loading.dm::decode_saved_value` entry recursion and list key/value recursion | Pass the same operation to Load_Entry and both recursive decode calls. Cached list/reference records are operation-owned. | Serializer; foreign/replayed token or reader fails before new writes. |
| Load_World allocation, recursive loading, after_load, level feed and bounded final verification | Check stable custody at each resumed batch/callback; return distinct typed progress until all expected levels and root rechecks finish. | One wrapper abort path covers initial allocation and final verification as well as per-level catch. |
| `functions.dm::loadmap` calls `load_map_metadata()` but currently ignores its FALSE return | Proposed opted-in path must require exactly TRUE or throw, under same operation/readers; metadata is finalized before restore proof publication. | Serializer aborts/quarantines missing or rejected metadata after world mutation. Ordinary behavior is a separate compatibility check. |
| `loading.dm::load_map_metadata` reopens map.txt and writes map fields | Bind metadata bytes to selected immutable generation reader; validate operation before writes and afterward. | Serializer; account/auxiliary pin owner joins final proof after metadata. |
| Wrapper resets persistence_save_in_progress after Load_World FALSE or exception | This Boolean release is not recovery. Publish/retain an operation-bound durable recovery block on any post-mutation failure; admission, economic issuance and checkpoint/map transition remain refused. | Serializer coordinates extraction recovery owner. The verified durable primitive and every consumer gate are prerequisites, not existing behavior. |

The current wrapper records `last_error`, clears bookkeeping on caught exceptions
and reports restart guidance; those actions do not implement persistent quarantine
or rollback. Cleanup must preserve the original failure, close readers once and
leave durable recovery intact even if cleanup itself fails. No Boolean completion
or successful level feed permits admission before final proof acceptance and the
separate, revalidated single-use admission capability.

Required source review before implementation: exact trailing-token signature and
all recursive callers; selected reader acquisition/release and host writer owner;
mutation-started/abort ownership covering allocation and metadata; rejection of
FALSE metadata completion; and recovery gates at admission, issuance, checkpoint
and mapswap. Required controls preserve actual ordinary-yield refusal and exercise
post-mutation metadata rejection, input replacement between phases, recursive foreign
token, initial/final abort and cleanup failure. These controls are not yet authored
or executed and do not replace accepted-subtype continuation closure.

Token and reader checks must precede the `Load_Entry` cached-object fast path,
which can write an existing object's location, and the `decode_saved_value`
cached-list fast return. Checking only before new construction leaves both
cached paths outside custody validation. Keep every positional Load_Entry
argument and named nocontents/lag_fix call compatible when adding the trailing
operation; cache membership is bound to that exact operation.

The storage constructor at `storage.dm::New` schedules `spawn(5)` to sum current
contents and update max_storage_space. Load_Entry construction can enqueue this
continuation before decoded writes, and it can run during or after restoration.
It needs an owner-reviewed operation-owned, deferred or blocking classification
and a post-resume custody check. Decode return and final census completion alone
do not fence it. This confirms that accepted-subtype closure must include delayed
constructor continuations, not just synchronous New/after_load bodies.

## Shared faction-war persistence implementation priority

Human priority now places shared faction-war persistence ahead of standalone
extraction. The following phases reuse the existing serializer, extraction
custody/journal and engine owners; they do not authorize bypassing the runtime
hold or editing another owner's shared files. Faction-war is an implementation
priority, while the unverified reader/host/closure prerequisites remain blockers.

| Phase | Concrete owned implementation target | Required acceptance before next phase |
| --- | --- | --- |
| 1 - durable shared generation | Serializer supplies the reviewed typed operation/readers/commit/restore entry plumbing; host owner supplies verified immutable generation custody and publication/quarantine. Extraction supplies its explicit policy adapter and joins. | Preflight leaves live world untouched; post-mutation failure keeps recovery; restart/replay, input replacement and ordinary null-policy controls pass on exact head. No fixture claims of multiweek stability. |
| 2 - faction assets and counterpart handoff | Shared adapter defines versioned mode/faction/server/generation identity, explicit supported equipment/vehicle graphs and a one-owner transfer journal. Export/import uses selected immutable inputs, compatibility validation and idempotent receipts; no export creates an unacknowledged second usable copy. | Same-server counterpart and separate-server staged handoffs preserve identity/condition/currency and reject wrong mode/faction/schema/generation, concurrent/replayed claims and interruption at every custody transition. Host authorization and destination ownership are explicit. |
| 3 - physical faction convoy | Faction-war owner binds expensive paid cargo to an actual shipment and escort vehicle reaching world extraction. Surviving vehicles return for reuse; destroyed vehicles require paid rebuilding. Gate to explicitly selected WWII-and-later faction-war modes, with reviewed era mapping. | Actual player escort/extraction/failure route, physical cargo and surviving/destroyed vehicle outcomes, durable save/restart and omission controls. No menu or journal-only fixture substitutes for player acceptance. |
| 4 - long-running rounds | Engine owner measures retained objects, callbacks/queues, persistence cost and repeated save/restart behavior on representative faction worlds; define recovery and bounded growth budgets before optimization. | Exact-head regression and runtime observations with duration/workload stated. Weeks-long stability requires correspondingly long representative observation, not accelerated fixtures or memory counts alone. |

Immediate coordination boundary: serializer owns shared persistence plumbing,
extraction core owns custody/journal adapters and inventories, faction-war owner
must supply the selected map/faction/era and counterpart compatibility contract,
and engine/host owners own runtime budgets and immutable external custody. Confirm
those owners and the smallest released shared patch before implementation. Bot,
mall and surface activation stay disabled until their independent acceptance.

Cross-server phase 2 inherits the ambiguous/failed no-refund/no-inferred-release
rule. Before destination assets become usable, source assets must durably enter
unusable reserved/export-pending custody. Lost acknowledgment, uncertain destination
commit or partition retains recovery custody; timeout never implies rollback,
refund or permission to re-enable the source. The journal decision and receipt bind
transfer ID, exact root identities, both server/mode identities and generations,
and expected source/destination revisions. Idempotent receipts alone cannot prove
exclusive custody. This is a contract prerequisite, not an implemented distributed
transaction; the authoritative journal and host custody owner must be selected.

## Scoped wrapper implementation pending verification

The current source candidate changes only `functions.dm` in shared production
persistence. `loadmap()` captures the selected storage/policy, acquires a bound
attempt when configured, validates preflight, obtains a recovery reservation and
rechecks bindings before ClearMap. Mutation-started is recorded immediately before
ClearMap, conservatively covering partial clearing exceptions. World loading must
succeed and metadata must return exactly TRUE before reporting a completed load.
The metadata rule deliberately fixes the old null-policy false-success behavior;
successful ordinary legacy/v2 restoration remains the compatibility target.

One failure path preserves the original error across failure-receipt, transient
release and bookkeeping exceptions. A post-mutation failure requires a typed
receipt bound to that attempt with recovery_retained exactly TRUE. Cleanup errors
remain separately visible; transient release is attempted once, including when
the success-path release fails. Acquisition failures before a bound attempt is
returned remain the provider's cleanup responsibility. Providers must retain
recovery independently of transient release; this interface does not finalize or
publish restore success. Runtime policy/attempt handles must not be serialized.

No production policy/provider is installed. The default opt-in policy fails closed
before clearing; null policy retains ordinary successful loading. The injected
actual-wrapper fixture and metadata/recovery omission controls require separate
recorded execution results. They can establish callback/receipt behavior
after execution, not durable reservation storage, immutable readers, host ABA
exclusion, a global custody fence or multi-tick census admission. `loading.dm`,
the save schema/readers, physical custody and engine behavior remain unchanged.
