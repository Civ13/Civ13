# Acceptance and bounded native plan

No native game/client run is authorized by this document. The coordinating owner
must review the bounded plan before any DreamDaemon/DreamSeeker launch. No server
restart, deploy, public activation, live save access, security/network setting or
credential change is needed for design, source editing or compilation.

## Deliverable and accepted decisions

This PR completes the expedition **design**: power, crossing, colonization,
identity/persistence and future acceptance contracts. It does not deliver a
playable doorway. The shared design #3346, JSON topology tool #3348 and disabled
power/identity foundation #3351 have merged independently. Their completion does
not complete the integrations below. The room-layout status correction #3402
records rejected version-1 previews; revised geometry remains unapproved.

Decision record dated 2026-10-28:

| Decision | Accepted scope | Evidence still needed for gameplay |
| --- | --- | --- |
| B1 | Outages stop ordinary travel both ways and preserve the colony. Require protected, prepaid emergency-return reserves before entry. | Native outage/return, reserve conservation, durable entitlements, complete paired saves and safe rescue. |
| B2 | One colony, eight residents, threats initially off, exploration and paid construction. | Authoritative body/capacity accounting, paid resource conservation, no-threat behavior and measured native headroom. |

Other cost/timing/footprint values remain provisional. Geometry approval and
implementation evidence are separate from policy acceptance; neither is inferred
from these decisions or a successful topology check.

Required B1/B2 acceptance cases once the corresponding integrations exist:

- Interrupt power before a request, during preflight and after arrival. Both
  ordinary directions close; the same instance, residents, construction,
  contents and spent-resource state remain, without regeneration or free travel.
- Before entry, atomically fund/reserve return rights for all living residents
  plus the entrant. Missing, malformed, exhausted or unprotected reserve rejects
  without movement, new charge or altered prior rights. Emergency egress still
  requires its independent power and its protected landing.
- Entitlements and body identities survive paired-world save/load. Logout and
  reconnect free no slot and issue no duplicate claim/kit; verified return/death
  releases only that body's matching claim.
- Eight living resident bodies, including disconnected/protected sleepers, fill
  the first preset. A ninth entry fails before debit/movement; observers do not
  count. Full inbound capacity cannot prevent safe powered return or rescue.
- The preset starts no hostile director/spawner. Building consumes real resources
  exactly once; cancellation preserves inputs. Reconnect, outage or template
  reload cannot restore spent materials or initial dressing.

## Remaining integration work

These are implementation dependencies, not missing B1/B2 policy decisions and
not reasons to represent the completed design as working gameplay:

| Gate | Exact remaining dependency |
| --- | --- |
| Geometry and native destination | Visually reviewed revised room families and purposeful furnishings; finite expedition recipe with return/colony anchors; pinned native palette/export and parse-back; materialized same-size planes. The rejected catalog/example output is ineligible. |
| Endpoint/instance ownership | Scenario-scoped pair and logical-level records with durable lineage, unique runtime owner/epoch, direction-specific anchors and stale-owner invalidation. Registration/lookup cannot confer level approval. No native z or memory reference may substitute for the durable instance ID. |
| B1 return and rescue | Protected paid reserve/entitlement ledger with bounded startup/hold/retry costs, exact replenishment debit, safe emergency pad/egress and obtainable facility rescue role. Ordinary maintenance/building cannot spend the reserve. |
| B2 residents and access | Authoritative living-body ownership, membership and eight-slot accounting, including disconnected/protected sleepers; coordinated inbound reservations and full-capacity returns. |
| Complete persistence | Both planes and scenario/body/resource/entitlement metadata in one complete world-save generation; preflight before mutation, current runtime-field exclusions, fresh-process restore and no partial recovery. Crossing must participate in save/load/recovery/restart exclusion. |
| Era and resources | Actual 1990/tier-7 spawn, loot, recipe and research allowlists, including prerequisites; finite food/water/material acquisition manifest and paid charge handler. Year labels and generic Modern kits cannot satisfy this gate. |
| Physical transfer | Pair serialization, exact native clearance, four ordinary landing reservations, no-yield movement/debit audit, rejection/reconciliation rules and committed shared cooldowns. No physical transfer is supplied by the power-state predicate. |
| Playable evidence | Measured two-plane/eight-resident runtime and save/import headroom, sustained supply balance, native boundary/save tests and connected-client entry/build/outage/return acceptance. |

No additional geometry choice is required to review this design. Before a native
map can be selected, recommend reviewing the revised room families and dressed
expedition manifest visually, then binding only their approved exact output.
Keep the one-colony/eight-resident/threats-off preset; tune reserve and supply
costs in a separate disabled implementation with conservation tests before play.

## Merged power/identity foundation

The independently merged source implements finite charge, powered lifecycle
admission and an immutable colony/content snapshot ABI, with no physical actor movement.
Tests must cover exact maintenance/startup boundaries, same-time idempotence,
loss immediately before admission, interruption during startup, late service,
shutdown/restart spending, depleted charge, invalid/fractional input, different
colony/content/era restoration and rejection without mutation. Disk round trips
must preserve charge/identity and restore OFF/disconnected, never runtime clocks.

Offline tests may inspect source contracts and prepare a byte-exact isolated DM
fixture. They are not native execution or gameplay. Compile against the actual
tools/byond/version.json target **516.1688**, retain full diagnostics, and report
compile versus execution separately. Historical 516.1681 probes stay unchanged.

Proposed native fixture for review: one standalone 1x1x1 headless world using only
the production gateway datums and deterministic assertions; no game startup,
assets, maps, clients, bots, SQL, HTTP, shell or live saves. Temporary directory
only; at most one trusted DreamDaemon process, 20-second deadline, bounded logs,
owned-process cleanup. Reject clients, disable hub visibility, close the port and
refuse reopening. An external socket census must prove no listener; Windows can
bind before world.New even with -close, so preserve any startup-socket failure
instead of relaxing the rule. No repeated launch or fallback to a live install.
Only a reviewed harness can launch it. The committed preparer does not launch.

Native fixture controls should independently remove outage admission, finite
debit and restore-OFF behavior in generated temporary copies, and must fail their
named assertions. Do not modify repository sources for controls. Save/load tests
use a new private test file per case. Preserve failed assertions and diagnostics.

## Physical integration and playable acceptance

Later separate source slices require these tests before activation:

- Landing occupied/dense/deleted; 4-pad deterministic exhaustion; exact actor
  clearance and real movement callbacks; same-tick competition for one pad.
- Power loss before reservation, during a delayed request, immediately before
  commit and immediately after successful movement; stale tokens after restart.
- Nonmembers, observers, dead/incapacitated actors, nested inventory, pulling,
  buckles, cargo, vehicles, reentrancy and shared bidirectional cooldowns.
- Save admitted before/after transfer, concurrent save refusal, paired-level
  durable save and fresh-process restore, mismatched/missing/duplicate identity,
  damaged metadata rejection before mutation, actual nested colony contents.
- Return at full capacity, disconnected bodies retaining slots/entitlements,
  all explorers inside during outage, independent supplies, paid emergency
  reserve exhaustion, protected landing/build limits and facility rescue role.
- Every loadout/loot/recipe's year/tier/research/prerequisite allowlist, including
  attempts to unlock Modern generators via an apparent 1990 date label.
- Exact selected yellow hazmat/half-mask/glove/boot kit from DESIGN.md: real
  equip/unequip/slot packing, four worn directions and transparent face opening,
  separate mask overlay, visibility/eyes, nested survey gear and reconnect/save
  without duplicate issuance. Compare suit-only, mask-only and full-kit behavior
  through actual smoke/filter/covered-body radiation paths before enabling any
  hazard that relies on them. Armor/flags and sprite inspection alone do not
  establish sealing, breathing protection or immunity. No consumable filter or
  oxygen mechanic is assumed. Initial rooms need none of those hazards.
- Shared generator export replay/parse-back, no escape flags required for return,
  unreachable branch/blocked egress rejection and no duplicate generator code.
- Functional room dressing: against-wall equipment retains a usable front
  approach; open-floor features preserve construction plots and connected
  walking clearance; narrow passages cannot receive dense blockers. Validate
  dressed geometry, deterministic manifest replay and rejection of a prop in a
  gateway/rescue/socket reserve. Save/outage recovery must preserve removed or
  built furnishings without regenerating the template's initial dressing.
  Review office desk/chair/filing/computer groupings against their actual room
  purpose and 1990 palette, including a deliberately unfurnished-room case;
  verify source prop placement is not mistaken for interactive machinery.
- Bounded two-plane lighting, weather/temperature policy, ordinary hunger and
  inventory, save/import memory headroom; population/capacity remains a design
  target until measured at the exact footprint and body count.

First full-game review plan should name exact commit, two-plane map dimensions,
toolchain/executable hashes, independent temporary state and adapters, exclusive
screen turn, process/port/deadline caps and cleanup. Then demonstrate genuine
surface startup -> deliberate powered entry -> exploration/build -> outage with
occupants intact -> independent survival -> powered emergency/ordinary return ->
reconnect/save restoration. Include actual screenshots and reproduction steps,
and video for startup/crossing interruption timing. Do not call the foundation,
an offline proof or a compiled fixture a working gameplay scenario.
