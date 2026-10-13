# Extraction custody and asynchronous fence inventory

Source baseline: `b9ef785b73f2515aa22df63fbdb0ab0eeff831d1`, October 13.
No helper, compiler, native runtime, client or resource query was executed.
This inventory supplies concrete integration boundaries for the serializer owner;
it does not establish an exhaustive global fence. All fence hooks below are
proposed, not implemented. Existing session locks and surface-root guards are
local contracts, not a substitute for that fence.

## Authoritative fields and mutation rules

Equipment custody uses each node's `extraction_item_id`,
`extraction_found_in_raid` (FIR) and `extraction_insurance_token`, preserved in
schema-2 codec nodes. An insurance token is not an owner credential: ownership
comes from durable claims, account stash/garage, mail indexes and shared receipts.
`insurance.dm` derives current owners/recovered status across those stores.
Account profiles bind canonical owner and revision; vehicle nodes additionally
use `extraction_vehicle_part_id`, and their cargo uses equipment IDs.

`equipment.dm::encode(assign_new_ids = TRUE)` and `set_raid_provenance()` can
assign previously missing IDs. Census paths use `encode(..., FALSE)` to avoid
minting IDs. A fence must distinguish read-only census from legitimate issuance,
paid transformation and retirement. An item's current location alone establishes
none of those authorities.

## Exact production boundaries and control gaps

Paths below are relative to `code/`; fixture paths are relative to
`tests/extraction/` unless another suite is named. "Missing" means no audited
production operation-token control establishes that boundary. Fixture coverage
is source inventory, not a new passing test result.

| Exact path and proc | Mutation and authority | Yield/re-entry exposure | Proposed fence boundary | Existing negative vector; missing control |
| --- | --- | --- | --- | --- |
| `modules/1713/extraction/equipment.dm::decode` | `new path`, deletes default children, sets IDs/FIR/token/scalars/refs/lists, force-moves every node, invokes every `after_load`. Requires exact account graph and one-use issuance authority. | Dynamically dispatched constructors, `forceMove` callbacks, material/reagent helpers and `after_load`; synchronous loop syntax does not prove callbacks cannot yield. | Check operation/capability before first constructor, after every dispatch and before every graph write/placement; quarantine partial issuance on loss. | `equipment_probe.dm` checks nested graph/quantity/identity and rejects malformed payloads; no production token-loss constructor/placement/after-load control. |
| `game/objects/items/weapons/storage/storage.dm::handle_item_insertion`, `remove_from_storage`, `quick_empty` | Direct `W.loc` writes and drop callbacks change parent/root membership; preserve existing node identity/provenance. | Native inventory/equip/drop callback dispatch; quick-empty cascade. | Explicit direct-location mutation gate and callback resumption check; cover nested nodes, not just surface roots. | Surface fixture rejects linked-root storage bypass; no fence-loss ordinary nested insertion/removal/cascade control. |
| `modules/1713/gunsmithing/gun_configuration.dm::install_configuration`, `remove_configuration` | Direct attachment `loc`, gun refs/attachment lists, `A_attached`; token/ID survive physical detach. Insurance covers purchase-time nodes only. | `wait_for_configuration` calls `do_after`; `unEquip`, `dropped`, recompute/update callbacks. Constructor `spawn_part` path skips actor wait. | Acquire graph mutation permit before both runtime and constructor installation; recheck after wait/drop and before ref/list/location edits. | `scope_insurance_probe.dm` detach/reattach and later uninsured attachment; gun_configuration suite checks interrupted work. No operation-epoch loss after successful actor checks. |
| `modules/projectiles/guns/projectile.dm::cock_gun`, `load_ammo`, `unload_ammo`, `consume_next_projectile`; `modules/projectiles/gun.dm` firing loop | Moves/deletes casing/projectile/magazine nodes and changes chamber/loaded refs; stable consumed IDs need explicit retirement semantics. | `cock_gun` sleeps 3 ticks; firing sleeps `_burst_delay`; actor callbacks and scheduled fire continuations. | Gate actual consumption/ref writes, and invalidate or defer burst continuations across operation epochs. | Codec fixture preserves loaded graphs; no freeze-between-shots/load/unload custody control. |
| `game/objects/items/stacks/stack.dm::New`, `Crossed`, `merge`, `split`, `use` | Changes amounts, creates split roots and qdels depleted roots. Neither merge nor split defines extraction ID/FIR/insurance inheritance. | Constructor/Crossed merge, icon callbacks and `spawn(0)` UI continuations. | Block/defer during census/restore; define paid split/merge ID/provenance policy separately before enabling mutation. | Equipment decode creates stacks at null and suppresses restoration Crossed merge with temporary throwing flag. No ordinary split/merge stable-ID conservation or fence-loss control. |
| `modules/1713/extraction/surface_loot.dm::claim_root`, `movement_allowed`, `observe_disposal`; item `Move/forceMove` overrides | Linked surface root requires authorized destination while busy; disposal quarantines and may commit disposing journal state. Descendants are not individually surface-bound. | Movement callbacks and journal helpers; direct `loc` writes bypass Move/forceMove. | Bind source permit to unified operation; reject/defer disposal during read fence; cover descendant mutation through explicit entry points. | `surface_probe.dm` movement/disposal/direct-storage/reconciliation vectors; no global permit or callback epoch proof. |
| `modules/1713/extraction/mode.dm::admit`, `save_home`, `deploy`, `extract`, `release` | Durable starter/debit/credit/checkpoint, physical decode/drop/delete/move, FIR clearing; authoritative session body/owner/revision. | Menus/confirmation and extraction wait; inventory, decode, garage and qdel callbacks. | Reserve global operation through each journal/physical transition, recheck after yields; consume issuance capability before decode. | `mode_probe.dm` changed actor/loadout/exits and identity refusal; no constructor or qdel callback stealing global epoch. |
| `modules/1713/extraction/vehicle_transfer.dm::capture/current/relocate` | Captures actual part locations and encoded cargo; relocation consumes once and force-moves actual parts/cargo. It never credits accounts. | `relocate` has no explicit waits/constructors, but each forceMove and matrix/corner helper dispatches production code. | Permit before first move and recheck after each dispatch; an interrupted partial relocation needs quarantine, not replay as untouched. | `vehicle_probe.dm` stale footprint/nested condition and new ID/FIR/token/containment rejection vectors. No loss between two part moves. |
| `modules/1713/extraction/vehicle_raid.dm::deploy_vehicle`, `extract_vehicle`, `extract_vehicle_riders` | Car-owner garage plus each rider's own equipment and fee; group receipt commits all projections before relocation. Driver wheel and riders move/unbuckle before extraction wait. | Confirmation menus, wait, unbuckle/forceMove and shared settlement. | Capture all participant/account/vehicle permits before first pre-wait mutation; recheck at every consent/wait and physical callback; ambiguous submit locks all participants. | `mode_probe.dm`/`group_probe.dm` fee/loadout/vehicle change and rider isolation; no epoch loss after unbuckling or between acknowledged receipt and part relocation. |
| `modules/1713/extraction/vehicle_codec.dm::decode`; `garage.dm::restore_garage/retire_garage` | Constructor defaults retired; sets vehicle refs/lists and direct `O.loc`; cargo calls equipment decode. Cleanup qdels identified roots/children. | Dynamic constructors, updates, nested cargo decode and qdel callbacks. | Operation-owned construction ledger from before `new`, token after callbacks/direct writes; retain failed graph membership for cleanup. | `vehicle_probe.dm` invalid graph/ID collision/fuel roundtrip; no callback yield after partially reconstructed vehicle. Vehicle decode does not invoke generic `after_load` for car parts. |
| `processes/human_corpse_decay.dm::try_retire_corpse` | Drops actual bounded corpse roots, constructs remains/zombie, calls `corpse_retired`, qdels body. Physical retirement does not credit account/mail or mint IDs. | `drop_from_inventory`, construction, hook listeners, qdel/Destroy dispatch. Body/location/record guards rechecked after drops, not a unified operation. | Physical owner supplies pre-retirement/drop/hook/deletion permit and post-callback check; defer process during fence or explicitly own retirement. | `scope_insurance_probe.dm` actual gun/components preserve ID/FIR/token/condition and no immediate credit; corpse-release omission. No operation loss in a dropped/hook callback. |
| `processes/garbage.dm::qdel`, `datum/Destroy/Del`; `processes/abandoned_items.dm` item lifecycle | Destroy and forced/direct deletion can move/retire graphs outside extraction. `qdel` removes location/queues legacy GC; null loc is not collection proof. | Destroy/Del subtype callbacks, process budget resumes, forced GC dispatch. | Physical/GC owner must gate before irreversible cleanup; token-own delayed retirement by saved identity, defer otherwise. | Corpse/abandoned-item/GC suites cover native lifecycle identities; no extraction fence-epoch controls in queued/forced deletion. |
| `modules/1713/extraction/account_store.dm::write_phase/commit_profile/recover_snapshot/settle_pending_loss/retire_pending_vehicle/retire_pending_delivery` | Intent/snapshot/commit slots and recovery receipts change selected account bytes; recovery ownership checks protect IDs. | File operations are not a host exclusion mechanism; overriding adapter/callback may re-enter. | All write/recovery projections share captured operation/pin identity; gate lowest write primitive and higher recovery read/validate/write chain. | `store_probe.dm` root-alias lease, direct child-journal writes, wrong digest/replay/ownership; no cross-host exclusion or token loss between recovery validation and write. |
| `modules/1713/extraction/settlement.dm::ready/repair_journal/submit`; `insurance_mail.dm` queue transactions; IPC polling | A readiness read may repair journal; multi-account settlement/mail/index writes change custody. Completed insurance generations govern eligibility, not corpse age. | Process polling/menu callbacks and adapter dispatch; repairs are mutations even without physical issuance. | Freeze every account/journal/index root together, distinguish read-only census from ready/repair, carry token through receipt acknowledgments. | Settlement/mail/IPC fixtures cover interruptions/replay/sharded node index; no whole pinned-set loss while readiness repairs another journal. |
| `modules/1713/extraction/home_replica.dm::prepare_home_retirement/retire_home_replica/bind_home_replica` | Binds marker owner/revision/digest and actual roots; prepared/retired receipt does not release privacy/admission. | Graph encode helpers and each qdel/commit; replay compares runtime refs. | Same operation for account, marker, graph removal and saved-world retirement proof; never infer missing roots mean persisted retirement. | Existing home_retire owner/partial/graph/remove/restart/prepare omission controls; no loss in root Destroy or between retirement receipt and world-generation publication. |
| `modules/persistence/loading.dm::Load_Entry/Load_World/decode_saved_value/load_map_metadata`; `functions.dm` save/load wrappers | Shared direct loc reuse, recursive graph reconstruction and pathname reopen; serializer owns reader and epoch plumbing. | TICK_CHECK, sleep(10), dynamic constructors and native world after_load. | Serializer must propagate one typed operation/reader identity through every recursion/yield/callback, not wrapper Boolean alone. | World-save fixtures are separate; offline generation oracle is unrun and does not exercise this boundary. No extraction native generation handoff is implemented. |

## Callback classification that changes implementation scope

The codec accepts broad projectile-gun, attachment, clothing and storage subtype
families, not only exact starter types. A constructor audit of a few starter items
cannot establish closure of this allowlist. Before activation, enumerate the
compiled accepted subtype set and audit each included `New`, `Destroy`, `Del`,
movement and interaction override plus whether it calls its parent. No such
compiled inventory was executed during this hold. Unsupported/unreviewed subtype
callbacks must remain blocking rather than being assumed synchronous.

Concrete callbacks already traced:

- `modules/projectiles/guns/projectile.dm::New` creates default ammunition and
  optics; the codec deletes defaults before assigning stored refs. Constructors
  register actual objects before the full graph is exposed.
- `modules/projectiles/ammunition.dm::ammo_casing/New` creates a BB and registers
  casing/abandonment state; `randomrotation()` schedules `spawn(1)` pixel changes.
  Pixel positions are not encoded equipment custody fields; nevertheless the
  deferred callback still needs lifetime/epoch classification. Magazine `New`
  creates stored ammunition synchronously.
- `game/objects/items/weapons/storage/storage.dm::New` schedules `spawn(5)` to
  inspect later contents and update `max_storage_space`. This is a delayed
  observation of the reconstructed graph, not proof of a yielding constructor.
- `modules/1713/gunsmithing/gun_configuration.dm::gun/after_load` calls its parent,
  resets busy state and recomputes links/icons. Its inherited
  `processes/abandoned_items.dm::item/after_load` resets/re-registers decay.
  `modules/persistence/functions.dm::datum/after_load` is currently a no-op.
  These bodies have no explicit sleep, but dynamic helpers still require checks.
- Native world loading also invokes human `after_load` in
  `processes/human_corpse_decay.dm`, which rebuilds dead/living lists and decay
  registration, and structure callbacks such as component workbench/car workshop.
  Those are not equipment-codec item issuance. Maintain separate native-world
  callback membership and equipment/vehicle constructor ledgers.

Priority gaps are direct-location/ref writes; ordinary stack identity policy;
callback-owned partial issuance/retirement; journal repair under a pinned set;
and subtype closure. The new vehicle vectors deliberately exercise existing
`current()` graph comparison. They neither install a fence nor simulate a passing
token check. All new assertions remain uncompiled and unrun. Shared serializer,
physical corpse, engine and launcher files were not changed.

## Minimal coordinated implementation requests and remote CI paths

Authorize these only after the serializer defines the unified operation permit
and its loss semantics. No shared-hook implementation is included in this batch.

| First hook proposal | Required discriminating negative control | Existing registration path |
| --- | --- | --- |
| Extraction `equipment.dm::decode`: check permit around constructor, placement and after_load; ledger every created node before exposing graph. | Inject ownership loss from a production-supported constructor/placement/after_load callback; refuse further issuance, retain quarantine/cleanup evidence. An omission must reach a named assertion. A fake successful Boolean fence is insufficient. | `tests/extraction/run.py --probe equipment`; `.github/workflows/test.yml` extraction step already runs it. Adapter/token loss controls are still missing. |
| Extraction `vehicle_transfer.dm::relocate`: permit before each part move and post-dispatch check, together with quarantine semantics agreed by vehicle owner. | Invalidate epoch from first part's movement callback; assert second part is never relocated and original transfer cannot replay. Existing new stale ID/FIR/token/containment vectors test preflight comparison only. | `run.py --probe vehicles`; existing workflow also runs `--vehicle-loss-negative-control`. A new callback-loss omission option needs a workflow command added with the implementation. |
| Extraction `account_store.dm::write_phase` plus recovery entry points: unified permit for every write and projection, captured root/account revision/pins. | Lose token after recovery validation but before first receipt write; require unchanged slots/receipts and recovery block. Cover a second store/root alias and shared mail/settlement child journal. | `run.py --probe store`, `test_recovery.py`, `run.py --probe settlement`; existing extraction workflow commands. Cross-host writer exclusion is a separate gate. |
| Shared storage/gun/stack/physical/GC hooks: serializer and owning worker define rejection/defer/operation-owned policy before modifying inherited code. | Direct loc/ref write after permitted preflight, gun completion after epoch loss, split/merge consumed-ID omission, corpse dropped/hook re-entry and forced retirement after fence loss. | Existing extraction scope/equipment/mode fixtures plus `tests/gun_configuration` and physical lifecycle suites. No global fence coverage is registered or implemented merely by those suite names. |

Selection is implemented by `scripts/select-ci.py::introduced_tests`, called
through `.github/workflows/ci-selection.yml`; the existing extraction suite guard
in `.github/workflows/test.yml` selects `tests/extraction` when introduced tests
qualify or extensive regressions are explicitly enabled. Editing an existing
probe alone does not auto-select regressions. A requested remote workflow must
bind its actual ref/head and suite selection before any result is called evidence.
No workflow, new CI command or dispatch was added by this audit. The Windows oracle
guard is not an executable Linux CI probe and does not prove these DM controls.

Also coordinate the native vehicle `axis.dm::startmovementloop/movementloop` and
component workbench `assemble/finish_assembly` paths: active movement and timed
paid transformation can mutate parts or consume/create items without going
through extraction relocation/codec. Existing busy/moving/actor checks protect
their local transactions but provide no shared operation epoch. Proposed controls
must revoke/defer those continuations, with original paid identity and no-refund
ambiguity retained. This inventory leaves broad subtype closure explicitly open;
no auth implementation is assigned here.

### Remaining physical-transfer identity controls

Source review of `vehicle_transfer.dm::current` distinguishes root identity
from nested identity. Footprint atoms are compared against the captured `parts`
references and locations, but cargo descendants are compared only through
`vehicle_cargo.dm::encode` and JSON equality. Replacing a nested atom with a
different atom carrying the same serialized ID, FIR, token and equipment values
is therefore not distinguished by this comparison. This is a source-derived gap,
not an executed reproduction. The new ID/FIR/token assertions change serialized
values and do not cover an equal-value replacement or duplicate identity outside
the captured graph. A coordinated fix needs a bounded captured descendant
reference roster as well as serialized state, plus the global duplicate-ID census.
The negative control should retain the original child outside the vehicle,
substitute an equal-value child inside its container, and require refusal without
moving either graph or issuing account credit.

`capture` refuses `axis.key_service_busy`, while `current` does not recheck it.
A key-service reservation acquired after capture is a separate stale-preflight
case. Proposed coverage should set the reservation after a successful capture,
require refusal with unchanged physical locations, then release it and verify
the original graph is eligible again. Both controls remain proposals here;
neither production hooks nor knowingly failing fixture assertions were added.

### Serializer review: validation and constructor exposure

Vehicle cargo encoding currently calls `equipment.encode(I)` with its default
`assign_new_ids = TRUE`. Both `capture` and `current` therefore can issue missing
IDs while checking eligibility, even if the resulting transfer is refused. The
read-only census uses `encode(FALSE)`; that property does not extend to these
vehicle paths. The coordinated hook must distinguish authorized issuance from
read-only comparison at `vehicle_cargo.dm::encode`, propagate that mode through
equipment traversal, and reject a missing ID without minting during validation.
Required negative controls clear a captured child's ID and introduce a previously
unissued child, then verify refusal preserves the missing ID, locations, journal
and account credit. The existing nonempty-ID drift assertion covers neither case.

`equipment.dm::decode` calls `new path(destination)` for non-stack items before
`created += I`. A constructor may place/register the root or create defaults
before returning; checks around `new` and enrollment after return alone do not
account for those effects across re-entry or a yielding constructor. Operation
identity and default-child enrollment must exist at the creation boundary, or
construction must be isolated with audited callback/registration constraints
and complete quarantine accounting before exposure. Apply the same requirement
to vehicle construction. This remains a source-derived risk, not evidence that
every constructor yields.

The proposed typed permit must pin the operation epoch, member/root identity,
authority and revision; propagate through recursion and waits; check immediately
before irreversible writes and after callbacks; and record partial effects for
recovery while rejecting replay. The shared saver's declared-transfer API is a
separate contract and is not an implemented global custody permit. Serializer
review accepts this document as an inventory proposal, with these gaps open.

### Narrow vehicle stale-capture source implementation

The subsequent source patch adds a bounded actual-member/parent/reference/list
roster to vehicle cargo snapshots, including the native wheel inside a wheel
crate. Validation compares that roster and serialized state, rechecks key-service
reservations, and passes `assign_new_ids = FALSE`. Default capture also refuses
unissued cargo. Reset, consumed transfer and destruction release cargo rosters;
all transfer snapshot fields explicitly opt out of custom persistence.
Equipment encoding preserves its existing defaults and adds an independent
`mutate_persistence` option; vehicle validation explicitly disables it, preserving
all item `should_save` flags on both acceptance and refusal. ID issuance and
persistence mutation are separate options.

Cargo's bounded member traversal rejects installed generator kits before calling
the equipment codec, avoiding `snapshot_installation`'s live broken-state refresh.
Portable kits still use the accepted equipment schema. This is a local eligibility
restriction, not a change to shared equipment serialization or a global fence.
The initial vehicle codec explicitly selects its existing issuance behavior;
that legacy subpath still lacks reviewed atomic refusal/rollback/quarantine
semantics and remains an activation blocker. No new issuance transaction or
global identity-sequence rollback was implemented.

`tests/extraction/vehicle_custody_probe.dm` uses the native assembled-car fixture
to isolate equal-value replacement with encoded equality, exact location
conservation, restoration, post-capture reservation, cleared/unissued IDs,
generator refresh refusal and runtime-field exclusion/reset. The existing runner
adds generated-source omission controls for roster comparison, reservation,
non-issuance and persistence mutation; each requires its named assertion and rejects unrelated errors.
These are source changes awaiting independent review and remote/native execution.
The new executable test selects the existing extraction suite through introduced
tests; the existing CI extraction step includes all four omission controls.
The packed wheel counts as a native descendant for the depth bound: a crate at
depth seven can retain its wheel at depth eight, while a crate at depth eight
is refused. A direct native-containment boundary fixture avoids the independent
cargo weight limit masking this check and verifies restoration after refusal.

### Remote evidence and corpse observation boundary

Run `38402321373` at `1dfebbaa0352b9c6180534b2d36573009e2f195a`
compiled the full project with BYOND 516.1681 and zero errors/warnings, but failed
in the equipment insurance fixture before the vehicle custody tests and four
omission controls executed. Those controls have no runtime result from that run.
The secondary missing fallout artifact followed its skipped suite.

Successful production corpse retirement calls `corpse_retired` before deleting
the human. The fixture must observe cleared hand slots inside that hook rather
than dereference the retired human afterward. A scoped, inert test hook retains
only a bounded receipt of exactly-once delivery, hand clearance and original
weapon placement. After retirement the fixture requires disappearance of the
human and the surviving weapon at its original turf, then checks unchanged
component identity, provenance, condition and account/insurance state. This is
a fixture observation correction; production retirement and item-drop callbacks
remain unchanged. Its compile/runtime result is pending independent source review
and remote verification.

Five separately named opt-in CI steps run the existing vehicle positive and
roster, reservation, issuance and persistence omission commands after an earlier
failure, unless cancelled. Each failed step still fails the job; the original
equipment failure remains blocking. Their independence provides diagnostic
results, not an exemption from required checks or activation blockers.
