# Live server directory contract (unreleased)

This candidate replaces the public BYOND port catalog with an HTTPS directory.
It is **not ready for release until both provider endpoints are deployed and the
end-to-end path is verified**. The shipped 1.0.4 executable and stable update feed
remain unchanged. Merging this code does not deploy the backend or publish an EXE.

## Trusted provider endpoints

- Civ13.com: `https://civ13.com/.well-known/civ13/servers.json`
- ValZarGaming: `https://valzargaming.com/.well-known/civ13/servers.json`

These are proposed routes, not endpoints demonstrated to be live. The existing
Civ13 site redirects to GitHub Pages; ValZarGaming's historical
`/servers/serverinfo.json` redirects to Twitch. Neither legacy location supplies
this contract. The provider must serve the well-known path directly over trusted
HTTPS, without redirects or cookies/authentication. Keep the path separate from
site-wide redirect rules. A reverse proxy may route it to Civilizationbot's
existing read-only HTTP service. Do not expose bot administration routes.

The backend config owns the inventory of enabled game-server keys and their
ports, not the launcher. It queries only those configured servers. No port scan,
DNS-derived inventory or browser-page scraping is performed. A successful, bounded
BYOND `status&format=json` probe supplies each entry; failed, disabled, incomplete
or stale records must be omitted. `online: true` is the provider's attestation of
that probe, not a claim that an empty game is offline or that the launcher opened
a game socket. HTTPS authenticates the provider's directory, not a BYOND session.

## Schema 1

Example only, using an arbitrary directory-supplied port:

```json
{
  "schema": 1,
  "generated_at": "2026-10-19T17:00:00Z",
  "expires_at": "2026-10-19T17:01:00Z",
  "servers": [
    {
      "id": "nomads-a",
      "name": "Nomads Europe",
      "host": "civ13.com",
      "port": 24017,
      "engine": "BYOND",
      "online": true,
      "checked_at": "2026-10-19T16:59:58Z",
      "players": 12,
      "map": "Europe",
      "mode": "Nomads",
      "epoch": "Modern",
      "round": { "id": "round-27", "duration_seconds": 7384 }
    }
  ]
}
```

- Respond with HTTP 200 and `Content-Type: application/json`. A fresh empty
  `servers` array is a valid report that no servers were verified online.
- JSON is at most 65,536 bytes, depth 8, and 32 entries. Duplicate property names,
  duplicate accepted IDs or duplicate accepted endpoints invalidate the document.
- All timestamps are exactly UTC `yyyy-MM-ddTHH:mm:ssZ`. The document lifetime
  must be positive and at most 120 seconds; the publisher should use 60 seconds.
  Generation must be less than 120 seconds old and not over 5 seconds in the
  future. It must not be expired at receipt.
- Each probe must be no newer than generation and at most 60 seconds older than
  generation. An entry is valid only until the earlier of document expiry or
  `checked_at + 120 seconds`. Allow at most 5 seconds of client clock skew.
- Host is exactly the selected provider's lowercase hostname, with no trailing
  dot, IP literal, URL, path or subdomain. Engine is exactly `BYOND`. Port is an
  integer from 1 to 65535; there is no compiled allowed-port or mode list.
- `id` is 1-64 ASCII letters/digits, `-`, `_` or `.`. Name is 1-120 characters;
  map 1-160; mode 1-80. Players is an integer 0-10000, never missing/unknown
  coerced to zero. Empty online servers remain selectable.
- Round ID is a string of at most 80 characters. An empty ID displays as
  unavailable. Elapsed seconds is an integer 0 through 2147483647. Optional
  round state is at most 40 characters; omit it if the game does not report it.
  Optional epoch is at most 32 characters. No player/account names are required.
- Display strings reject control characters, Unicode formatting/line separators
  and surrogate code units. Additional fields are ignored for forward-compatible
  additions; required fields are never inferred. Invalid, offline, incomplete
  or stale individual entries are hidden. An invalid envelope fails closed.

Civ13's existing `code/datums/world_topic.dm` exposes `players`, `map_name`,
`map_gamemode`, `map_age`, `game_id`, and `round_duration_in_ticks`. Derive
`duration_seconds` from ticks divided by 10. Do **not** use
`round_duration_in_second`: its current implementation multiplies deciseconds
by 10. The game does not currently provide a reliable round-state field.
Civilizationbot can adapt these public status values without publishing its
private config, player names, Discord data or admin credentials.

## Launcher behavior

Each provider visit fetches a fresh snapshot. Requests have one 8-second total
budget including headers and body and a 64 KiB streaming cap. They do not follow
redirects and request no-cache/no-store. There is no persisted or bundled live
fallback. Timeout, missing route, wrong content type, stale data or invalid JSON
shows an unavailable message with Refresh and Back.

The menu displays name, player count, map, mode, optional epoch, round ID,
elapsed round time, host/port and checked/expiry times. It is an explicitly dated
snapshot rather than a continuously updating player counter. Refresh fetches
again. Selection re-fetches the directory before dispatch; the same ID and exact
host/port/engine must remain present. A changed or vanished target requires a new
selection. Freshness is checked again after DNS and immediately before starting
the verified native client.

Civ13.com still passes only its fixed hostname to DreamSeeker. ValZarGaming
still performs fresh DNS verification and passes only its existing approved IP;
the excluded/changed address rules are unchanged. The directory cannot substitute
another host or engine. BYOND 516.1681 detection/installation, Pager sign-in,
local receipt verification, updater controls and experimental OpenDream operator
flow are unchanged. Public BYOND selection still rejects `--server-port`.

## Verification and rollout gate

1. Deploy the separately reviewed Civilizationbot adapter and configure each
   provider's enabled server keys. Confirm its bounded probe and no-secret output.
2. Configure both public HTTPS routes and prove that redirects cannot move them
   to the website, Twitch, GitHub Pages or an arbitrary origin. Check TLS normally.
3. Compare each reported record against the actual configured service and a fresh
   game status response. Confirm zero players remains online, a stopped server
   disappears, a new configured port appears without rebuilding the launcher,
   stale output expires, and failed/incomplete probes never become live entries.
4. Run Windows launcher CI for the exact commit, then check the actual provider
   menus and a genuine BYOND join using the existing authorized account/session.
   Offline responses do not establish production availability or game acceptance.
5. Only after acceptance, separately bump the launcher version and publish an
   immutable release through the existing reviewed flow. Do not overwrite 1.0.4
   or activate this candidate on the stable feed while either endpoint is absent.

Tests: `dotnet run --project tests/Launcher.Tests.csproj -- --directory-only`
runs the offline directory contracts on .NET 8. The normal Windows suite includes
these tests plus the existing updater, native-client and executable replacement
checks. All HTTP/DNS/game-process effects in the directory suite are injected;
there is no scanning, real game connection, credential use or production mutation.
