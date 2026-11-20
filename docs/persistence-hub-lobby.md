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
independently before moving public entry links.

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
  gameplay admission and authoritative character homes. The lobby must not
  write to that ledger or claim that a character is new on lookup failure.

## Proposed implementation

1. **Separate world and supervisor.** Build a minimal, opt-in lobby target
   with no map save, playable characters, round ticker, bot webhooks, or
   idle freeze. Start on its final public port with public visibility; do
   not use a standby port or rebind. Give it its own health checks, bounded
   restart backoff and logs (no credentials or raw player identity in public
   diagnostics). A game update or failure must not stop the lobby.
2. **Read-only routing decision.** From the authenticated BYOND session,
   look up the character's home in the existing authority. Use the
   configured start region only when the lookup explicitly says no home.
   Wake the chosen region through the existing coordinator/host interface
   and wait for readiness, not just an open socket. Use the configured
   relay or other existing verified handoff for that region; never accept a
   host, port, or character key as client-supplied routing authority. The
   destination still makes the admission decision. On timeout, dormancy
   without enough memory, or missing authority, keep the player in the
   lobby with a specific retry message; never redirect back to the lobby
   or create a replacement character. Rate-limit retries and coalesce
   wakes for the same destination.
3. **Separate entry from status.** Keep the website redirect, launcher
   Play destination and Discord Play link on 1714. Add a distinct
   launcher entry target type or field so a lobby reply proves only that
   the entry is up. Regional status, population and admin/bot routing must
   resolve a real gameplay region through the approved discovery/host
   configuration, not be pointed at the lobby. Do not advertise a backend
   address to the public launcher if the region is behind the relay.
4. **Preserve doorman and launcher behavior.** Keep the doorman on 1713
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

## Staging and cutover

1. **Inventory, read-only.** Identify the actual listeners, service owners
   and NAT rules for doorman 1713, Gaia 1714, and all gameplay, standby,
   transfer, relay and control listeners. Verify a free backend port using
   both configured/reserved ports and active listeners. Inspect the shard
   group's plan without applying it. Record existing join/status baselines
   and snapshot the relevant group, generated region and bot configuration.
   Refuse a port collision, a busy handover, unhealthy saves, an unsafe
   network assumption, or an unknown listener owner.
2. **Validate on a spare, isolated port.** Use fake/sandbox home, wake and
   relay services. Demonstrate returning character, new character, missing
   home authority, sleeping region, readiness timeout, low memory,
   failed relay, and restart-during-handoff. Confirm neither reroute nor
   gameplay restart changes character ownership. Verify concurrent users
   from one public IP do not silently complete the wrong transfer; the
   existing per-address relay's limitations are documented above. Exercise
   launcher browse, Wake & Join and handoff with the supported release(s),
   including status provenance, approved endpoints, low-memory refusal
   and deadlines; if an alias exists also test its framing, strict scope,
   rate limits and refusal paths. Confirm no privileged request reaches
   the private service.
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
   generated host/region, relay and bot/status routing through the
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
port, generated routing and bot/status configuration, and start the same
authoritative Gaia save on 1714. Never run two gameplay writers against
one save or restore an old copy over successful new play. If the current
save cannot be verified or the listener owner is unknown, stop the cutover
and escalate rather than overwrite data or kill an unknown process. Recheck
direct joins, launcher status/wake on 1713 and regional administration.
Public joins continue to use the same 1714 URL; no DNS/link rollback is
required if the plan was followed.
