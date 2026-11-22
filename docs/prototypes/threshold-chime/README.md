# Custom spellwork composer

**Design draft only.** Save the [standalone HTML](threshold-chime.html) and open
it in a browser. It is a synthetic demo of composing, approving, sharing and
simulating bounded spells, not Civ13 gameplay. All locations, people and
authority are fictional. It does not contact a server or create items.

## Compose, review and grant

1. Choose an **existing in-world repository accessible to the caster's
   province**. Every spell needs one. The sample repository is not a claim
   about an existing type or a proposal to spawn a new one.
2. Wire one typed trigger to one target selector and compatible effect. Start
   with explicit allowlists, no freeform DM, arbitrary script/callback,
   chains, loops, fanout of effects or circuit item. The chime and lift
   presets are examples, not the only legal graphs.
3. Review the exact graph with its resolved repository and any fixed
   endpoints: authorized source, trigger condition, anchor/scope, radius,
   target cap and caster inclusion, effect, duration and cooldown, and cost.
   A separate authorized patron grants or refuses that immutable request.
   Cancel/edit invalidates it, including stale pending grant screens. Refusal,
   expiry and invalid approval cost nothing. A valid grant spends one
   available slot and consumes one item already in the caster's pouch. Magic
   changes existing objects or bodies only, never creates them.
4. Applied graphs survive normal saves/restarts. Changed or inaccessible
   repository or approved endpoints suspend rather than relink. The
   original casting mage, another currently eligible mage with verified
   discovery of this exact binding, or its patron God can remove it. A
   genuine world reset clears the old lineage. Ordinary players are never
   shown the graph, binding, endpoints or owner by this interface. Hearing a
   bell or knowing an endpoint does not confer discovery.

## Typed examples

| Recipe | Trigger and source scope | Selector | Effect |
| --- | --- | --- | --- |
| Threshold Chime | One approved existing door **finishes opening** normally | One approved ordinary local bell (no church bell) within 3 tiles of the trigger origin, same region/floor | Ring locally with the ordinary bell's own cooldown and no identification of the opener |
| Phrase Lift | The casting mage's own direct IC utterance of exactly **What's up?**; within approved repository/province scope | Up to 4 eligible existing mobs within 3 tiles of the mage's validated speech origin, same region and starting floor; caster exclusion is the example default and can be explicitly changed before approval | Rise at most one building level to the second floor, only along open headroom; stop/bump at an obstruction and do not phase through it. Hold only successfully lifted mobs for 3 seconds, then release to normal gravity |

A typed trigger emits the same minimal signal independently of the target
selector. A selector binds either a validated bell or a bounded group of
mobs; the effect must accept that type. The prototype permits compatible
cross-combinations with those anchors and illustrates radius and duration
choices from 1 to 3. A real dynamic origin must stay in the approved
repository/province region and area; deny rather than silently broaden it.
Local bell distance for any source is checked again at delivery. Only
successful transitions and direct speech can emit. No unlock, OOC message,
other speaker, relay, echo, replay, generated speech or restored state can
impersonate the source. Match the exact authored phrase, define and test the
input normalization in the live hook, and do not leak the phrase matcher to
ordinary players. Bound feedback, cooldown, queue and per-event/per-target
work before dispatch; ordinary bell cooldown always applies. Use server-owned
event identity and deduplication rather than a timestamp as proof of authority.

### Lift implementation boundary

- Resolve the **actual second building level** one level above the eligible
  ground origin. Do not infer it from raw `z=2` or `z+1`, treat cave or
  practice levels as upstairs, or allocate a z-level. Follow
  [building-level resolution](../../../code/modules/multiz/standing_building_level.dm)
  and the native vertical transition/collision rules. Before each target's
  move, check the path and destination for ceilings/solid floors, dense
  obstacles and occupants, valid footing or approved open air, and eligibility
  to move. Resolve stacked/competing targets deterministically and recheck
  occupancy per move. Stay put if the move is blocked. The demo shows a
  ceiling bump without new injury; ceiling damage is not specified here.
- [Open-space entry](../../../code/modules/multiz/open_space.dm) can start falling
  synchronously. Use a narrow target-specific transient hold installed before
  attempted entry, rollback on failure, and release through normal gravity/
  fall handling. Do not toggle global gravity, force-move past collision,
  teleport a failed target, bypass ordinary fall effects, or let a repeated
  pulse extend or stack the hold. Cancel or clean up on removal, replacement,
  death/deletion, transfer, revoked scope and failed movement. If a target has
  already left or died, do not move the replacement or resurrect it. The HTML
  step clock merely illustrates open shaft, ceiling, occupied tile, range and
  release; it does not establish native physics or damage behavior.

## Export and import

- An eligible mage can export a spell they created by copying a **versioned
  local JSON blueprint**. They decide whether and where to share it. The demo
  uses copy/paste, no upload, external requests or public spell library. A
  future file picker/download may use the same local-only format.
- Version 1 has only `version` and a `spell` object: name, typed trigger and
  phrase setting, selector, effect, radius, hold seconds and caster inclusion.
  No provenance/permissions, live operator/owner/object/repository/binding
  identifiers, coordinates, discoveries, approvals, costs paid, runtime
  data, saved grants or pulses. No raw DM or authority payloads. A blueprint
  can contain the creator's own phrase and name, so inspect it before sharing.
- Enforce a size ceiling and strict schema, field types, names, min/max bounds,
  allowlists and compatible typed edges. Reject unknown versions, properties
  or injected privileged fields. Treat imported names/phrases as plain text.
  Import produces an **unbound, inert, editable draft**: reselect an eligible
  repository and every fixed endpoint in this world, then request ordinary
  approval and pay only on a successful grant. Import never binds, activates,
  grants discovery, spends resources or creates inventory.

## Runtime and acceptance follow-on (not implemented)

- Reuse the existing [covenant](../../../code/modules/divine/covenant.dm) and
  [one-use approval](../../../code/modules/divine/approval.dm). Revalidate
  current scope, access, identities, owner/whitelist and relevant endpoint
  positions at request, grant and delivery; at grant also recheck caster
  session, patron claim, slot, focus, and already-held material. Consume only
  in an atomic valid grant. Check any object or actor directly on the server,
  never trust IDs or roles from UI/import.
- Apply door hooks after [Open commits](../../../code/game/objects/structures/door.dm)
  through the [completion hook](../../../code/game/objects/structures/door_fittings.dm).
  Limit eligible door families; casements/trapdoors share that hook. Reuse
  [ordinary bell operation](../../../code/game/objects/structures/bells.dm)
  and the [Wiremod signal vocabulary](../../../code/modules/wiremod/README.md),
  not electronics permissions, a hidden circuit item or editor queues.
- Save only the **applied** graph, with schema, stable endpoints, authority
  scope, original caster/patron, stable binding ID, world lineage and verified
  per-binding discovery, coherently with the matching world-save generation.
  Restore silently after object identity resolution, with no new charge and
  no replay. No pending approvals, event dedup state, queued pulses, gravity
  holds or active effect timers are saved; settle transient targets using
  ordinary fall/persistence rules without inventing a held save state.
  Unknown, ambiguous, destroyed, moved or revoked endpoints suspend; never
  rebind by tile, name, or type. Remove only with fresh narrow authority.
- Test valid chime and exact phrase lift, wrong speaker/phrase, OOC, echo,
  locks, cooldown/duplicate events, radius/inclusion, ceiling/occupied upper
  tile, release timing, cleanup after target loss/removal and live save/load.
  Test stale edits/approval, invalid and replaced endpoints, no inventory
  creation, second-floor resolution (including a cave spoof), and same-link
  restore/removal/world reset. Round-trip both blueprint examples and reject
  missing fields, invalid names/types/bounds, mismatched nodes, extra
  authority/coordinates and unsupported versions. Exercise import/rebind
  request/approval, both no-charge failure and single-cost successful grant.

No production source, gameplay, public changelog, live changes or Night
Vigil are included here.
