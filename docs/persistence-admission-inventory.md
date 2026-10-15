# Restore reconciliation and admission inventory

Source baseline: `81abda93498945e61dbeade6963f4b6ffa83aab4`. This is an
implementation proposal, not an installed gate or a tested provider. The inventory
covers current explicit world-load callers, extraction admission/deployment and
ownership materialization paths, plus generic login routes. Dynamic admin actions
and general atom movement make source coverage different from runtime proof.

## Existing entry points and proposed gate locations

Paths below are relative to the repository. Insertions are proposals only.

| Entry or bypass | Current source behavior | Proposed insertion before side effects |
| --- | --- | --- |
| `code/setup.dm:161` | Startup calls `ticker.loadmap()` | Reconcile host recovery before trusting the loaded world or enabling durable admission; do not trust wrapper TRUE as finalization |
| `code/modules/persistence/admin.dm:24` | Admin calls the same loader | Acquire the same operation gate; prohibit reload during unresolved recovery rather than create a second reservation |
| `code/modules/persistence/functions.dm:258` | Optional policy wraps validate, clear, restore, metadata and release | Bound reserve plus durable mutation-started before ClearMap; explicit verification/finalize outside transient release |
| `code/modules/client/client_procs.dm:166` | Client initialization calls parent, which invokes mob Login | For a selected durable world, block playable attachment before parent Login can activate an existing body |
| `code/game/mob/login.dm:37` and living/new-player/human Login overrides | Generic login and mind/icon initialization do not consult restore recovery | Shared selected-world admission check before playable attachment, including reconnect and direct key transfer; lobby/observer policy must be explicit |
| `code/game/jobs/job_controller.dm:611` | Newly relocated extraction humans call `admit` | Check recovery before relocation/issuance as well as in `admit`; rejecting only after relocation is too late for a global admission barrier |
| `extraction/mode.dm:438` `admit` | Calls ensure_round, opens account, assigns body/house, issues starter kit, restores garage and stash | Gate before ensure_round/account access and revalidate before each issuance; preserve existing account locks |
| `extraction/transactions.dm:36` `open` | settlement_ready, mail recovery, profile load; old raid converted to home | Gate before settlement repair/profile access; recovery must precede old-raid conversion |
| `extraction/transactions.dm:74` `active` and service `settlement_ready` | Session operations consult shared local reconciliation readiness | Add selected-world recovery readiness centrally; ready must not trigger repair while a restore is unresolved |
| `extraction/mode.dm:387` `owned` | Active session, body and account identity checks | Inherit recovery denial for interactions; this alone does not stop a connected body's free movement |
| `extraction/mode.dm:511` `deploy` | Saves home, debits raid loadout, then moves body | Gate before save/debit and after yielding confirmation; operation lease must remain bound across the mutation |
| `extraction/groups.dm:107` `deploy_party` | Plans and commits group/vehicle movement | Gate every member and shared transaction before durable debit; retain lease through physical movement |
| `extraction/vehicle_raid.dm:111` `deploy_vehicle` | Paid garage debit precedes physical vehicle transfer | Gate before planning/debit and retain exact operation custody through movement |
| `extraction/mode.dm:556` extraction and vehicle extraction/riders | Credits returned ownership and retires raid copies | Gate before credit/retirement; deny partial recovery-world settlement, not just new deployments |
| `extraction/native_market.dm:53` | Settlement re-admits the human after releasing the old session | Gate before the settlement transaction, and keep `admit` gated after it; post-settlement rejection alone does not prevent debit |
| `extraction/transactions.dm:77` `commit`, account store commit/recovery methods | Sessions check active; lower-level store methods can write directly | Bind approved normal transaction or recovery operation at store boundary; recovery requires a separate explicit capability |
| `extraction/settlement.dm` repair/submit and insurance/mail/bot journal paths | Local readiness and journal operations can repair/write outside a live session | Freeze normal repair/issuance while world recovery is unresolved; allow only host-authorized reconciliation, not a generic ready bypass |
| `extraction/garage.dm:27`, `mode.dm:490`, `raid_round.dm:78` | Decode saved vehicle/stash/returned equipment | Gate before constructor/decode; cover callers that do not create a new account session |
| `extraction/loot.dm:241` and `surface_loot.dm:368` | Durable container debit or source plan materializes live equipment | Gate before debit and decode; surface scheduling may run without a player session |
| `extraction/vehicle_codec.dm:311` | Cargo decode within vehicle restoration | Inherit exact parent restoration capability, never authorize from destination coordinates |
| `extraction/raid_round.dm` ensure/close and `hub_maps.dm` map swap | Initializes round journals, settles closures and executes external map swap | Gate initialization/settlement and prohibit swapping unresolved recovery identity out of existence |
| Generic admin spawning, direct key reassignment and atom movement | Can bypass extraction terminal/admit methods | Common client/world gate and selected-world mutation fence required; enumerating terminal callers is insufficient |
| Cross-server faction ownership transfer | No selected durable faction transfer API identified in scoped persistence/extraction sources | Missing host/admission input; existing save-transfer hooks are intra-export relocation, not cross-server custody |

Here `extraction/` means `code/modules/1713/extraction/`. Generic login files were
searched for extraction/restore gating; no corresponding recovery check was found.
Normal session readiness is not proof that a connected body, background issuer or
direct store writer is fenced. The proposed gate must also invalidate an admission
capability when operation/process binding is lost during a yielding action.

## Actual formats and unresolved production selection

Current map storage is `map_saves/`, with completion marker and map metadata;
`loading.dm` accepts legacy saves and format version 2. Current account default is
`data/extraction_accounts/`, account schema `EXTRACTION_STORE_VERSION = 1`.
Equipment graphs retain supported legacy and version-2 representations; garage
records use schema 1. Preserve each existing validator, not a new faction schema.

The current auxiliary census in `surface_inventory.dm:15` enumerates settlement,
groups, insurance, rounds, NPC, bot and mail journal roots beneath the account-root
prefix. This inventory must be selected exactly with the account/map members,
including expected absent members; copying only map levels cannot restore coherent
ownership. It does not prove external writer exclusion or exhaustive production
faction storage. `data/safehouse_spool/` is an IPC default, not a selected durable
broker journal location or a selected cross-server custody provider.

Production faction map/root/server identity, exact schema/member selection,
cross-server transfer owner and final recovery/admission decision policy are
MISSING. Account directory comments assuming one authoritative server are not an
authenticated stable server identity. Do not derive one from hostname, ckey,
world.time, PID or current map ID without the owning contract.

## Smallest implementation-ready adapter slice

Once the selected host API exists, the first slice is an optional runtime-only
reconciliation adapter shared by `restore_policy` and extraction service readiness.
It carries stable server/world/root identity, operation/generation/member binding,
host recovery ID and a separate process-instance identity. Startup begins blocked;
`recover_pending` must complete authoritative reconciliation before any normal
readiness can return TRUE. Unknown/unavailable host state stays blocked. Ordinary
null-policy loading remains supported; it cannot authorize durable faction state.

Reserve must durably mark mutation-started before the first disposal. Restore
verification and finalization require explicit callbacks, while close/release only
drop transient readers. Finalize is idempotent for identical durable fields and
decision; conflicts reject. Lost acknowledgments require journal lookup. A new
authenticated process reconciles the existing durable record but obtains fresh
selection handles and admission capability. A runtime Boolean never clears host
recovery or substitutes for a committed final decision.

The disposable prototype uses a unique owned directory per run. Persist a selected
test world/root ID and stable test server ID across two process instances; rotate
only process identity. Place broker journal/recovery in a sibling directory outside
the prototype world rollback tree. Preserve legacy/v2 map and existing account and
auxiliary schemas with exact manifest membership. All inputs are synthetic; no
production configuration, account files or faction schema is introduced.

Automated targets include pending recovery blocking new login and reconnect,
admin reload rejection, existing-session deployment/settlement denial, direct
store/background materialization denial, stale capabilities after yield, durable
mutation marking before first disposal, restart with fresh process binding,
same-operation retry, conflicting-finalize rejection and lost-ACK reconciliation.
They require the actual adapter and host API; fixture receipts alone cannot prove
durable custody. No parser, helper, compiler, native process or deployment is
authorized by this inventory.
