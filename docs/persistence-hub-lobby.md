# Permanent Persistence Hub lobby on TCP 1714

Design and migration proposal. This document does not install a world,
allocate ports, or change any live routing.

## Goal

Run a small, independently supervised BYOND world on public TCP **1714**. It
is the stable Persistence entry on the BYOND Hub and hands players off;
it does not host gameplay. In a scheduled cutover, move Gaia's game listener
to a preflight-verified free backend port, retaining the same region ID,
canonical save and lifecycle owner. Do not assume a port is available or
move the existing standby, doorman or relay ports. Current public links to
1714 do not change.

A reachable game port and visible DM world do not prove Hub listing. A static
lobby removes Gaia's standby rebind from the Hub registration path, but does
not establish that the rebind caused the missing listing. Verify listing
independently before the listener cutover.

## What already exists, and what does not

- The [shard group's gate and relay](../scripts/shard-group/README.md#two-public-ports-routing-relay)
  already wake a character's region and hand the client to the relay. The
  current gate is a *playable* region. [Changing it](../scripts/shard-group/README.md#ports-and-the-front-door)
  swaps game ports and can also change which world the bot watches. Do not use
  `set-gate` to install this lobby.
- The [launcher discovery contract](../tools/opendream-client/native/SERVER-DISCOVERY.md)
  treats the doorman as status/wake only. [HostStatus.cs](../tools/opendream-client/native/HostStatus.cs)
  fixes that endpoint at **1713** and depends on the BYOND Topic text reply
  format and JSON schema 1. The launcher still verifies the configured game
  endpoint separately. A lobby must not masquerade as gameplay status.
- The [host doorman](../scripts/gaia-host/README.md#the-doorman-serve)
  uses 1713 by default. Keep its listener and public API intact; this plan
  does not move the doorman. The launcher correlation and wake target are
  still port-based: old clients match the advertised instance port and ask
  `?wake=1&port=1714`. A new listener alone would silently change what those
  requests mean.
- The [region relay](../code/modules/persistence/region_relay.dm) and
  [transfer storage](../tools/transfer_storage/README.md) already handle
  gameplay admission and authoritative character homes. The playable gate's
  login calls `/account` with `op=claim`; [the account agent](../tools/transfer_storage/region.py)
  can enqueue a claim to establish a home. This is an admission operation,
  not a read-only lookup, and must not be called by the lobby.

## Proposed implementation

1. **Separate world and supervisor.** Build a minimal, opt-in lobby target
   with no map save, playable characters, round ticker, bot webhooks, or
   idle freeze. Start on its final public port with public visibility; do
   not use a standby port or rebind. Give it its own health checks, bounded
   restart backoff and logs (no credentials or raw player identity in public
   diagnostics). A game update or failure must not stop the lobby.
2. **Read-only routing decision.** From the authenticated BYOND session,
   ask the existing authority through a genuinely read-only operation.
   Distinguish a verified home from authoritative no-home and from
   pending, travelling, or unavailable state. Use the configured start
   region only for authoritative no-home; a missing, stale, or failed
   answer is not permission to redirect a player as new. No lobby lookup
   may enqueue a claim, establish custody, change a home or admit a
   character. Wake the chosen region through the existing coordinator/host
   interface and wait for readiness, not just an open socket. Use the configured
   relay or other existing verified handoff for that region; never accept a
   host, port, or character key as client-supplied routing authority. The
   destination still makes the admission decision. On timeout, dormancy
   without enough memory, or missing authority, keep the player in the
   lobby with a specific retry message; never redirect back to the lobby
   or create a replacement character. Rate-limit retries and coalesce
   wakes for the same destination. A sent BYOND link is not proof of
   arrival. The [relay](../scripts/gaia-host/relay.py) expires an unused route
   after 60 seconds; if a handoff is declined, delayed, or fails, keep a
   visible way back to the lobby and let an explicit retry recheck ownership,
   readiness, and route expiry. Never guess a different destination or
   assume that a previous relay route is still valid.
3. **Separate entry from status.** Keep the website redirect, launcher
   Play destination and Discord Play link on 1714. Add a distinct
   launcher entry target type or field so a lobby reply proves only that
   the entry is up. Regional status, population and admin/bot routing must
   resolve a real gameplay region through the approved discovery/host
   configuration, not be pointed at the lobby. Do not advertise a backend
   address to the public launcher if the region is behind the relay.
4. **Remove direct-gate assumptions before cutover.** Moving Gaia's port
   does not change `send_player()`: today it links directly to the
   configured gameplay gate even with the relay enabled. If Gaia's
   backend becomes private, ensure external arrivals for Gaia use the
   relay just like other private regions. Use a separate public lobby
   address for the [reboot rejoin notice](../code/world.dm), the relay's
   fallback reconnect text, and [tutorial return](../code/modules/1713/tutorial_region.dm).
   Regions panel links, admin sends that reuse the travel helper, and
   other callers must not hand a private gameplay address to an external
   player. Keep intentional local operator access distinct.
5. **Preserve doorman and launcher behavior.** Keep the doorman on 1713
   with its current query framing, schemas and rate/wake policy. Teach
   the updated launcher to separate the stable lobby entry from its
   gameplay status/wake target; keep fresh DNS and endpoint validation.
   Before cutover, either verify all supported launcher versions can
   distinguish the new lobby from Gaia, or implement and test an explicit
   transitional compatibility contract for older versions. Any compatibility
   alias for `wake=1&port=1714` is scoped to Gaia's registered backend and
   must preserve low-memory refusal and rate limits; a status alias must
   disclose which world actually supplied the data and preserve framing.
   Do not assume a wake alias alone fixes old clients, which also verify a
   game response on their configured port. If that full flow cannot be
   preserved with correct status, require the launcher upgrade before
   cutover. Do not send privileged requests through the public lobby.

## Reserved services and internal gameplay ports

The host configuration owns a single port inventory. Public service
reservations are **1713** (launcher doorman), **1714** (Hub lobby and player
entry), and the existing configured public relay transport port (only if
enabled and verified; no new number is assumed). Keep the coordinator,
relay control, transfer agents, standby/maintenance listeners and other
shared-service ports in a separate private reservation set. Preserve
existing access policy: a reservation allocates ownership, not a public
bind, firewall exception, or router forward. Gameplay listeners are
reachable only through approved internal interfaces and the public relay.
Do not redirect a public client to a private daemon address.

The [existing group allocator](../scripts/shard-group/shard_group.py)
fills omitted ports once in the group config; it does not issue runtime
leases. Keep that behavior for existing static deployments. In opt-in
lobby mode, route by stable region ID, not an endpoint supplied by a
client or inferred from a port number. The host supervisor should lease a
port from a configured private pool when a dynamic world wakes, excluding
public and private reservations, explicit static allocations, other
leases and actual listeners. Verify the daemon actually owns the expected
listener before marking the generation ready. If a bind races another
process, fail closed and retry allocation within a bounded budget, not by
stealing the listener. Do not auto-renumber running or statically
configured worlds; add dynamic regions incrementally.

Publish a generation-bound endpoint only after game status and admission
readiness are checked. The pool lease belongs to the region/process
generation and stays held during warm idle or handover; preserve existing
authorized maintenance semantics and never pool the same port against
two saves or writers. Relay registration must follow endpoint ownership:
a generation change revokes old routes/registers the ready replacement
before reuse, even when the new owner gets the same number. An old
in-flight or sticky route must never land at a different owner after port
reuse. Free the port only after the old listener and its relay references
are gone, or keep it quarantined until then. A registry error, stale lease,
or unknown port owner produces retry/refusal, not a public direct link
or a guessed port. Preserve explicit static leases and the old registry
and relay settings as part of rollback.

## Staging and cutover

1. **Inventory, read-only.** Identify the actual listeners, service owners
   and NAT rules for doorman 1713, Gaia 1714, and all gameplay, standby,
   transfer, relay and control listeners. Verify a free backend port using
   both configured/reserved ports and active listeners. Inspect the shard
   group's plan without applying it. Record existing join/status baselines
   and snapshot the relevant group, generated region and bot configuration.
   Refuse a port collision, a busy handover, unhealthy saves, an unsafe
   network assumption, a missing relay for a private backend, or an unknown
   listener owner.
2. **Validate on a spare, isolated port.** Use fake/sandbox home, wake and
   relay services. Demonstrate returning character, confirmed no-home,
   pending and travelling accounts, missing home authority, a sleeping
   region, readiness timeout, low memory, failed relay, and restart
   during handoff. Verify a declined or expired handoff never has
   side effects on character ownership, and an explicit retry gets a
   fresh route without guessing a destination. Check external joins to
   private-backend Gaia, the Regions panel, manual reboot rejoin links,
   automatic relay reconnect, and tutorial return. Verify concurrent users
   from one public IP do not silently complete the wrong transfer; the
   existing per-address relay's limitations are documented above. Exercise
   launcher browse, Wake & Join and handoff with the supported release(s),
   including status provenance, approved endpoints, low-memory refusal
   and deadlines; if an alias exists also test its framing, strict scope,
   rate limits and refusal paths. Verify allocator exclusion of reserved,
   static and occupied ports, concurrent starts, bind races, standby lease
   retention, stale route rejection after port reuse, and pool exhaustion.
   Confirm neither public clients nor public status responses can reach or
   advertise a private gameplay/control endpoint directly.
3. **Verify real Hub registration separately.** An authorized staging host
   and an approved non-production Hub entry are prerequisites; do not list
   a staging world under Space Station 13. Confirm the lobby appears and
   is joinable from an external client while the staging gameplay world
   restarts or sleeps. Observe the configured Hub listing and an actual
   redirect; a listening port, `world.visibility = 1`, or
   `world.reachable = 1` is insufficient. Record the pinned build and
   results. This is a deployment acceptance check, not a source-PR gate.
4. **Schedule an authorized cutover.** After staging and launcher
   compatibility pass, announce the maintenance window, drain transfers,
   save Gaia, verify that save completed, take the standard backup, and
   stop the old listener. Update the shard group's Gaia port and its
   generated host/region, relay registry and bot/status routing through the
   supported workflow; do not change the region ID, save directory or
   character-home records. Verify the old gameplay process is stopped
   before opening the same save on the new backend port. Start Gaia on
   that port and verify loaded save, readiness and operator access, then
   start the lobby on 1714. Check the Hub listing, joins using the unchanged
   website/launcher/Discord destinations, handoff, and the doorman on 1713.
   Maintain an operator fallback route to Gaia according to the existing
   access policy; do not publicly expose the backend just to make a fallback.
5. **Observe before declaring success.** Verify a newly joined returning
   player and a new player arrive at the expected playable region. Check
   sleeping and unavailable destination behavior, Hub visibility, old and
   current launcher behavior, and that Gaia's running gameplay process is
   independent of the lobby. Record who owns the endpoint and rollback.

## Rollback

If listing, handoff, launcher compatibility or operational health regresses,
pause new handoffs and stop only the lobby first to free 1714. If Gaia's
backend world has begun accepting players, quiesce it, drain transfers and
verify a fresh save before stopping it. Restore the exact prior Gaia game
port, generated routing, lobby/allocator and bot/status configuration.
Invalidate the withdrawn backend generation's routes and start the same
authoritative Gaia save on 1714. Never run two gameplay writers against
one save or restore an old copy over successful new play. If the current
save cannot be verified or the listener owner is unknown, stop the cutover
and escalate rather than overwrite data or kill an unknown process. Recheck
direct joins, launcher status/wake on 1713 and regional administration.
Public joins continue to use the same 1714 URL; no DNS/link rollback is
required if the plan was followed.
