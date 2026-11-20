# Threshold Chime: player-flow prototype

**Design draft only.** Save the [standalone HTML](threshold-chime.html) and open
it in a browser. All characters, locations, object identities and simulated
authorities are fictional. The repository shown is an example, not a proposed
item, construction recipe, or claim about an existing BYOND type. The prototype
does not contact a game server, create items, or grant real authority.

## Player flow

1. Open Beseech after learning the prayer. First select a player-visible
   **existing in-world repository available to your province**. The spell will
   not provide or create a repository. Then select one eligible existing door
   and one ordinary local bell. Every candidate must be within the caster's
   permitted scope. A missing or ineligible repository blocks the request.
2. Review the exact trio: **Through:** the repository. **When:** the selected
   door finishes opening. **Then:** ring the selected bell. Church bells are
   excluded. Submit one immutable request; cancelling or editing retires it.
3. A separate authorized patron sees and approves or refuses that exact trio.
   They cannot substitute targets. Refusal, cancellation, expiry, lost access
   or a changed target costs nothing. A valid grant spends one available
   invocation slot and consumes one item **already in the caster's pouch**.
   It creates no inventory, endpoints, item copies or other physical objects.
   Magic modifies only objects already in the world.
4. The ordinary door still needs its normal access to open. One committed
   opening sends one local pulse. Denied openings, closing, and loading an open
   door send none. The ordinary bell shares its manual cooldown and identifies
   no opener; a pulse during cooldown is dropped, not queued for later.
5. The applied binding survives routine saves and restarts. A missing,
   moved, replaced or revoked repository, door or bell suspends the link. It
   cannot ring while invalid, and nothing automatically binds a substitute.
   It ends only when the original casting mage, another eligible mage who
   discovered **this exact link in-game**, or its patron God removes it, or
   when the world is genuinely reset. Removal ends only the enchantment; the
   world objects remain.

The simulated counterparts, pending/active states and debug controls are not
visible to ordinary players in the proposed game. An ordinary viewer neither
learns that a binding exists nor learns its endpoints or owner from this UI.
The prototype buttons for patron approval, discovery eligibility, removal,
restart, and world reset exercise fictional fixture authority. Viewing an
ordinary object, hearing the bell, knowing a tile, or opening this UI does not
grant discovery. Do not publish a public changelog or add player-facing
documentation or discovery surfaces as part of this design draft.

## Runtime follow-on (not implemented)

- Build on the existing [covenant](../../../code/modules/divine/covenant.dm)
  and [one-use approval](../../../code/modules/divine/approval.dm). Resolve
  actual server-owned identities for repository, door and ordinary bell at
  request time. Recheck existence, stable identity, location, anchoring and
  applicable scope, access/ownership, and province eligibility at **request,
  grant and signal delivery**. At grant also recheck body/client, active
  patron claim and whitelist, original request, focus, slot and existing
  pouch item. Reject unauthorized/self approval and stale or modified scopes
  before consuming anything; only valid consume/charge/apply is synchronous.
  There is no change to other prayers.
- Add an explicit record for the **applied** binding, not a saved magical
  item or general circuit graph. Store separately from transient prayer state:
  stable binding ID, world lineage, province/authority scope, exact stable
  repository/door/bell identities and approved positions, original caster
  identity, patron identity, and binding-specific discovery proof with its
  subject. Use existing persistence conventions and commit it with the same
  world-save generation. Do not serialize live object refs, pending approvals,
  or queued/in-flight pulses. Resolve the complete record after normal objects
  load; restore the same binding ID and valid discovery silently, never charge
  or ring on restore. Missing or ambiguous identity and revoked scope fail
  closed. Keep the record suspended rather than cancelling it on somebody
  else's behalf. Never match a new object merely by coordinates, display name,
  or type. A world reset changes lineage and rejects all old binding records.
- Removal needs a fresh server check: exact original caster identity with the
  applicable mage authorization, or another currently eligible mage holding
  verified discovery of this binding ID in this world lineage, or the
  authorized operator acting as the same patron God. No generic admin,
  electronics, ownership-of-one-object, or nearby-player shortcut. Support
  authorized removal of a suspended record. Recheck before commit so a stale
  dialog cannot revoke a different binding.
- The [door completion hook](../../../code/game/objects/structures/door_fittings.dm)
  runs after [Open commits state](../../../code/game/objects/structures/door.dm).
  Gate exact supported door families; casements and trapdoors also reach the
  base hook. Keep a single eligible same-region/z-level repository and one
  anchored endpoint of each kind. Start with caster adjacent to the door,
  both endpoints visible, and up to three tiles between the door and bell.
  Add no permission to unlock, identify or track players. No fanout or chains.
- Share the [Wiremod pulse vocabulary](../../../code/modules/wiremod/README.md).
  The timestamp payload is not a unique ID or proof of authority; use a small
  server-owned adapter, not a hidden circuit item or editor queue. Reuse the
  [ordinary bell operation](../../../code/game/objects/structures/bells.dm)
  behind its existing local cooldown. Electronics gain no magic permission,
  and the component-parity PR is not a dependency.
- Native acceptance must cover missing repository; moved, revoked, destroyed
  and same-tile replacement during pending and active use; refusal with no
  charge and no item creation; successful authorized removal versus a mage
  who discovered a different link; ordinary viewers; successful open,
  locked/closed/cooldown controls; and an actual save/restart versus a world
  reset, with no pulse, pending approval or extra cost on restore. This HTML
  fixture does not establish those results in BYOND.

No production source, game activation, wiki, live server change, or Night Vigil
work is included in this draft.
