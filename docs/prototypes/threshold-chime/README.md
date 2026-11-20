# Threshold Chime: player-flow prototype

**Design draft only.** The [local HTML prototype](threshold-chime.html) uses
synthetic fixtures. Save the file and open it directly in a browser. It needs
no server, account, external assets, network requests, or game connection. The
patron controls simulate a separate authorized person rather than grant real
authority. This is not an in-game screenshot or a BYOND test.

## Player flow

1. Open Beseech after the follower has learned the prayer. Choose one eligible
   door and one ordinary bell, then inspect: **When: the door finishes opening.**
   **Then: ring the nearby bell.** Church bells are not selectable.
2. Submit one request. The follower holds position; cancelling or editing
   retires the pending request. Nothing is spent while the request is pending.
3. A separate eligible patron sees the exact endpoints and effect, and can
   grant or refuse. Timeout, refusal, caller/session change, withdrawal, or
   endpoint change invalidates the request. Only a successful grant spends the
   normal invocation slot and one pouch item.
4. The active local binding survives normal open/close cycles for this world
   session only. A door that actually finishes opening emits one pulse. A
   locked/rattling door, the close transition, and a restored open door emit
   none. If the bell is cooling down, drop the pulse rather than retrying it.
   The bell makes its ordinary local sound and identifies no opener.

The browser demo controls simulate caller-side approval rejection, endpoint
movement before and after grant, expiry, locking, cooldown, and restart. No
public announcement, player discovery, crafting unlock, map placement, runtime
game code, Night Vigil, or production activation is proposed in this draft.

## Runtime follow-on (not implemented)

- Use the existing [covenant](../../../code/modules/divine/covenant.dm) and
  [one-use approval](../../../code/modules/divine/approval.dm) flow. On grant,
  revalidate the active body/client, patron claim and whitelist, spent slot,
  focus, component, one pending request, and exact endpoint identities before
  synchronous consume/charge/apply. Enforce separation of follower/operator
  for this invocation without changing other prayers. Never trust client-supplied
  refs, inventory flags, or the preview's simulated authority.
- The [door completion hook](../../../code/game/objects/structures/door_fittings.dm)
  runs after [Open commits state](../../../code/game/objects/structures/door.dm).
  Gate the eligible door families explicitly; the base hook also runs for
  casements and trapdoors. Add no permission to open, close, unlock, identify
  or track a player. Never emit from initialization or load.
- Share the [Wiremod pulse vocabulary](../../../code/modules/wiremod/README.md):
  a momentary typed signal, not a boolean level or an entity handle. Its numeric
  value is a world-local time and cannot establish identity, uniqueness,
  permission or replay. One output invokes one receiver through a bounded
  server-owned adapter. Do not create a hidden integrated-circuit item or call
  its item/editor-bound execution queue. Electronics do not gain a route to
  magical listeners; no dependency on the component-parity PR.
- Only a supported anchored door and an exact ordinary anchored bell stand,
  same world and z-level. For implementation review, start with the caster
  adjacent to the door, both endpoints visible, and at most three tiles
  between endpoints. Require authorization at each endpoint; do not treat
  mere visibility, proximity, a display name, or possession of a ref as
  permission. Permit at most one binding per endpoint; no fanout, chains,
  cross-region traffic or arbitrary target/command selection. Consume no
  resources when admission fails.
- Reuse the existing [ordinary bell operation](../../../code/game/objects/structures/bells.dm)
  behind a shared cooldown; preserve the manual ring path and exclude the
  world-wide church bell. Recheck selected endpoints just before activation
  and delivery. Movement, deletion, replacement, anchor loss or revocation
  retires the binding, including leave and return. No persistent pointer, ref
  string, live approval or timer in a save. A restart clears bindings without
  restoring effects or repaying consumed resources.
- Native acceptance must demonstrate one ring on committed open; no effect on
  unlock alone, refused opening, close, church bell, stale/replayed approval,
  endpoint replacement/movement/anchor change, depleted resources, active
  cooldown, shutdown, or load. Check real BYOND UI, actor/session transfers,
  ordinary doors and manual ringing. Browser-fixture checks do not establish
  game behavior.
