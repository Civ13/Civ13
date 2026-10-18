# Disabled gameplay bridge contract checkpoint

This slice builds on merged contract checkpoint
`670f415240c1634dcfb6e373da15cd86d84d676a`. The bridge remains excluded from
`civ13.dme`; the production feature macro is absent. No world, client, listener,
model, live query, configuration or credentials are activated. Compile-only CI
is separate from native execution and connected-client acceptance.

## Discovery and versioning

Run with a verified Python executable from the repository root:

```text
<python> -B scripts/gameplay_bridge/bridge.py discover
<python> -B -m unittest discover -s tests/gameplay_bridge -v
```

Discovery is offline and starts no listener. `catalog.py` shares typed action
arguments/enums with the Python validator, operation schemas, states/reasons and
fixed limits. It generates `code/modules/gameplay_bridge/catalog.dm` key/type/enum
guards; a source contract rejects drift. Availability is disabled_source_only,
not installed availability, permission or native acceptance.

DM emits version3. The same Python mailbox explicitly retains legacy version2
observations/receipts for historical tooling, rejects1, and refuses version
switches within an assignment. Existing /v1 URL paths remain: envelope version
and URL routing are separate. No new endpoint, host, port or credential scheme.

## Ordinary player authority and current adapters

Assignment still requires an existing consenting ordinary non-admin human and
an existing local R_ADMIN operator choosing per-capability permission. Proposals
cannot select another actor, assign, possess or create accounts. Consent never
follows respawn. Current actor/client/body/generation and mechanic eligibility
are rechecked. The existing inactive role-separated loopback mailbox is retained.
No real secret or example config was imported. Own-Host diagnostics remain a
separate admin plane and never supply player authority or hidden observations.
Names, descriptions, recipe labels and rendered chat are untrusted game data.

The14 fixed actions remain narrow ordinary-mechanic adapters: cardinal walk,
examine/use, pickup/drop/swap, flashlight belt equip, consume, gather, refill/drink,
fixed craft, plain say, help/grab/walk intent. Movement uses normal client.Move
on exact dry reviewed terrain/clutter; item/water/recipe/speech handlers retain
normal range, visibility, cooldown, costs, permission and postconditions. Unknown
subtypes do not inherit permission. No generic click/Topic/href, arbitrary
code/proc/type/field/file, raw ref or world scan exists.

Fixed recipes: grass twine, sharpen stick, bind flint axe, leather canopy and
deploy canopy. Sapote/base cup and ordinary water handlers preserve actual
contamination/ingestion. Shelter uses supplied leather and ordinary research,
recipe/payment/site rules. Receipts alone cannot prove natural Life service,
native resource conservation, bilateral hearing or rain protection.

## Stable observations and deltas

IDs increase monotonically within an epoch and remain stable only for currently
visible entities and own held items. Bounded private maps are rebuilt per snapshot;
visibility loss/deletion drops the ID, reappearance gets a fresh ID. IDs encode
no raw ref/name/coordinate/type. Numeric exhaustion stops before reuse. Bounds:
same z/radius3,256 visits,128 nearby rows,2 hands; own/cardinal turfs sampled first.
Existing native view, conservative lighting/normal-sight, eye/FOV/invisibility
and public-family restrictions remain. No private contents/ckeys/minds/roles or
other-player inventory is exposed.

`complete` and `limit_reason` explicitly identify visit/entity/output truncation;
a limited set never proves absence or safety. Oversized DM snapshots discard
rows AND target maps. Python allows at most24576 encoded ASCII-JSON observation
bytes, reserving space inside32768-byte envelopes; DM checks encoded snapshot
and outbound packet lengths, Python independently checks encoded bytes and caps
HTTP responses. Non-ASCII expansion can fail closed. Depth16/text/count limits
remain. No response may silently widen the sample or query hidden state.

POST /v1/observation with{} returns full state. Version3 additionally accepts
`{version:3,epoch:<opaque>,base_seq:<positive integer>}`. Delta responses include
base/current sequence, public entity/inventory upserts, removed IDs, current
status/capabilities/messages and next action sequence. Apply removals first; an
upsert moves its ID out of the opposite section before inserting. Removal means
absent from the observable set, never why/where it went. Messages are the current
bounded listener-filtered buffer, not guaranteed lossless event history.

History retains at most4 snapshots/131072 bytes with owned copies. Missing or
evicted base, wrong epoch, or either partial set returns kind:snapshot with
reset_required:true. Discard previous client state on reset. No hidden history.

## Results, idempotency and cancel

Submission keeps exact version/assignment/epoch/observation_seq/action_seq/
request_id/action fields. Same-ID identical retries return the cached receipt;
changed payload conflicts.64-record retention plus monotonic sequence prevents
replay after eviction. Status/cancel uses the EXISTING action path and controller
role with exact fields, for example synthetic-only input:

```json
{"version":3,"operation":"status","assignment":"synthetic-a","epoch":"synthetic-epoch","request_id":"request-1"}
```

Operation cancel addresses only that own scoped ID. Queue cancel is terminal
before dispatch. Inflight cancellation is cancel_requested, bound to the original
lease's request ID on the next existing exchange. It is not worker quiescence
or rollback. Only the original returned worker may publish cancelled. Already
completed effects can win the race; completion remains completion. Cached typed
receipts are not converted again on replay.

V3 receipts have request_id/status/reason/detail. States: queued, dispatched,
reserved running, completed, denied, cancel_requested, cancelled, failed, unknown.
Dispatch is not execution; running is not emitted without a game acknowledgement.
Completion requires adapter postconditions, not queued acceptance/model claims or
handler TRUE alone. Denials use fixed reasons and do not distinguish hidden from
missing targets. Legacy2 keeps its explicit old states.

After30sec without an inflight receipt, status becomes unknown/transport_uncertain
and the slot stays occupied. Cancellation can still be requested; a genuine later
receipt can resolve uncertainty. No second worker, new-ID automatic retry,
timeout cleanup or success inference. Local STOP revokes generation; remote STOP
latches the mailbox but cannot claim the game is quiet. Scoped status stays
readable after STOP while observations/new actions are unavailable. No invented
percentage or retrospective engine event trace.

## Explicit first-gather wait context

Only the enabled isolated profile advertises timed gather. Its worker passes the
original lease directly through execute -> survival_action -> canonical grass
handler -> grass_cutting_wait -> do_after. Operator JSON cannot supply context.
The helper accepts ordinary null context. Non-null input must pass an explicit
runtime type check, current singleton/service/lease/body/target/request/generation
checks and a one-use claim before survival_action_started. The captured original
lease is checked after every wake and after cleanup, including zero delay. A new
lease never substitutes for an old one. Grass checks it again before turf/output
mutation; completion checks the original worker and two-cutting output afterward.

No ambient actor/global lease lookup exists in enabled code. Ordinary null-context
waits do not claim or observe the bridge lease. Existing may_do_after and
check_for_repeats behavior, including FALSE-first overlapping-wait unlock behavior,
is preserved. Survival callback placement and cleanup are retained. No new mob or
client loan state is introduced; the lease datum has should_save = FALSE.

Readiness is per action: only gather is converted. Refill, drink, sharpen/bind and
canopy timed adapters remain unavailable. Immediate grass twine is unchanged.
Floor water handlers and ordinary attackby dispatch are unchanged. This is source
integration, not native cancellation, resource conservation or player UI proof.

The restricted conditional projector handles only the two reviewed symbols and
fails on unsupported conditionals. It is calibrated for nesting/active defines;
whole disabled file projections for helper, grass and both bridge files are pinned
to public670 hashes. It is not a general DM preprocessor. wait_overlay.py now
validates the actual explicit helper and prints its exact diff; the bundled patch
matches it. Production DME and disabled projection retain stock text/behavior.

Agent Join, containers, general equipment/repair, rest/sleep, combat, respawn,
vehicles, shuttle, party and extraction are explicitly unsupported. Assignment
requires an already joined human. No direct spawn, lobby authority, admin bypass,
automatic possession or mode-state setter. New bodies require new consent/epoch.
Player lawsets remain null; they cannot grant station/admin authority.

## Verification and next integration

Offline tests run actual Python schemas/mailbox/history/rate/idempotency/cancel
with synthetic data and inert transports. Source omission controls plus abstract
ownership/callback oracles cover forged context, replay/nesting, cancellation,
old/new lease isolation, unrelated waits and callback placement. They do not
execute DM or prove native timing/visibility. No private Git objects are required.

CI registers offline checks and three module compile-only closures with pinned516.1681:
stock excludes the module/macro, disabled includes the module without the macro,
and enabled includes the module with explicit gather context. They share frozen
tracked source/static assets and isolated1x1 startup, with no server config.
Three additional stock/disabled/enabled compile-only targets compile the actual
gather fixture. Each compiler invocation is bounded to180sec; CI step ceiling22min. Per-profile
logs and a source manifest are retained without binaries. An owned clean detached
expected-head worktree avoids generated crafting-atlas contamination. Exact-head
CI must establish0errors/0warnings for each; no compiler has been run locally for
this slice. Compilation never launches a daemon or client.

Historical headless/client probes used ambient leases and unconverted craft
adapters. prepare_native.py refuses those profiles even at a clean current head.
The dedicated prepare_gather.py now builds concrete typed gather fixtures with
reviewed external executor bindings, named omission profiles and no native start.
Their runtime results remain not_run. Original evidence is retained in the
original frozen checkout and cannot accept this revision. See [gather acceptance](gameplay-gather-acceptance.md)
for packet preparation, the missing native cancellation/parity and ordinary
consent/bootstrap proof.

Agent Join remains unsupported. Physical native Join/menu acceptance and genuine
pre-save lighting baseline remain separate core/UI work. Backend actions cannot
substitute for them. Broad survival/mode claims need their own evidence.

Restart required: yes for any later activated DM change. Offline discovery needs
no restart. This source checkpoint authorizes no deployment or native execution.
