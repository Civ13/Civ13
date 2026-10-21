# Live server directory contract (unreleased)

This candidate replaces the public BYOND port catalog with an HTTPS directory.
It is **not ready for release until the central directory serves both providers and the
end-to-end path is verified**. The shipped 1.0.4 executable and stable update feed
remain unchanged. Merging this code does not deploy the backend or publish an EXE.

## Central HTTPS authority

Both menus fetch the same fixed HTTPS authority and path, with one exact,
allowlisted provider query:

- Civ13.com: `https://civ13.com/.well-known/civ13/servers.json?provider=civ13.com`
- ValZarGaming: `https://civ13.com/.well-known/civ13/servers.json?provider=valzargaming.com`

The query is a provider selector, never a URL, DNS name to probe, or port override.
Only these two canonical raw query strings are valid. Extra/repeated parameters,
encoded alternatives, missing queries and unknown values are not part of the
contract. The launcher constructs the URLs internally and validates the exact
response URL, including its query. It never accepts a redirect.

These are proposed routes, not endpoints demonstrated to be live. Civ13.com must
serve the well-known path directly over trusted HTTPS without cookies or
credentials, separate from site-wide redirects. No ValZarGaming HTTPS endpoint
is required. A reverse proxy may route this path and its unchanged query to
Civilizationbot's existing read-only HTTP service. Do not expose bot administration
routes. Civ13.com is the trusted directory authority for both inventories;
per-entry host checks still prevent one provider's records from joining another.

An unconfigured provider returns HTTP 404 and appears unavailable. A configured
provider with no verified online servers returns HTTP 200 with a fresh empty
array. One provider's availability must not select or reuse another's snapshot.
The backend limits the combined configured inventory to 32 entries and each
response to 65,536 bytes; the launcher independently enforces both response caps.

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
- `id` is 1-64 ASCII letters/digits, `-`, `_` or `.`. Name is 1-120 UTF-8 bytes;
  map 1-128 UTF-8 bytes; mode 1-80 UTF-8 bytes. Players is an integer 0-10000,
  never missing/unknown coerced to zero. Empty online servers remain selectable.
- Round ID is a string of at most 80 UTF-8 bytes. An empty ID displays as
  unavailable. Elapsed seconds is an integer 0 through 2147483647. Optional
  round state is at most 40 UTF-8 bytes; omit it if the game does not report it.
  Optional epoch is at most 32 UTF-8 bytes. No player/account names are required.
- Display strings accept valid printable Unicode, including supplementary-plane
  characters such as emoji. Limits count UTF-8 bytes, not UTF-16 units or displayed
  graphemes. Malformed UTF-8, unpaired/reversed UTF-16 surrogates, and Unicode
  control/format/line/paragraph separator characters are rejected. Additional
  fields are ignored for forward-compatible additions; required fields are never inferred. Invalid, offline, incomplete
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

Both providers resolve their exact approved hostname afresh before each join.
There is no permanent public-IP pin: a changed valid public IP is accepted.
The obsolete individual parking-IP exclusion is also removed; the same public
address rules apply to every answer.
The candidate requests IPv4 A records, accepts 1-32 answers, rejects the entire
answer set if any address is private, loopback, link-local, multicast, reserved or
otherwise unsupported, and deduplicates the validated addresses. For BYOND,
fixed read-only status queries try those literals sequentially on the selected
directory port, within one three-second DNS/connect/read deadline. Each address
receives an equal share of the remaining budget; there is at most one active
game socket. Only complete valid status matching the selected map, mode and
nonempty round ID can select an address. Player count and elapsed time may
advance naturally. A silent, malformed or incomplete first address does not
consume every later address's budget. This is bounded best-effort selection:
short slices or an exhausted deadline can still leave a slow service unavailable.
The operator-only OpenDream path retains its separate address selection; it does
not send BYOND queries to an OpenDream service.
IPv6-only game hosts are unavailable in this candidate. The conservative IPv4
exclusions follow the [IANA IPv4 Special-Purpose Address Registry](https://www.iana.org/assignments/iana-ipv4-special-registry/),
including its special-purpose ranges even where an individual exception is
marked globally reachable.

The immutable endpoint result is bound to its approved hostname and expires after
15 seconds on a monotonic clock. Dispatch passes its validated IPv4 literal to
DreamSeeker, avoiding a second hostname lookup between validation and connection.
The same fresh-address policy replaces the old IP pin for the experimental
OpenDream operator path. DNS may still use the operating system's resolver cache;
this code does not alter machine DNS settings. DNS and HTTPS directory trust do
not authenticate the game session cryptographically, prove port ownership, or
control any later reconnect/redirect performed by the third-party game client.
A failed or stale resolution never falls back to a compiled or cached IP.

The directory cannot substitute another host or engine. BYOND 516.1681
detection/installation, Pager sign-in, local receipt verification, updater
controls and the explicit OpenDream operator-port requirement remain unchanged.
Public BYOND selection still rejects `--server-port`.

## Verification and rollout gate

1. Deploy the separately reviewed Civilizationbot adapter and configure each
   provider's enabled managed server keys or explicit status-only targets. The latter
   must not construct managed game services or require local game directories.
   Confirm bounded probes, public-address validation and no-secret output.
2. Configure the central HTTPS route and both exact provider queries. Prove that
   redirects cannot move them to the website, GitHub Pages or an arbitrary origin.
   Check TLS normally and verify unknown/extra query parameters are rejected.
3. Compare each reported record against the actual configured service and a fresh
   game status response. Confirm zero players remains online, a stopped server
   disappears, a new configured port appears without rebuilding the launcher,
   stale output expires, and failed/incomplete probes never become live entries.
4. Run Windows launcher CI for the exact commit, then check the actual provider
   menus and a genuine BYOND join using the existing authorized account/session.
   Offline responses do not establish production availability or game acceptance.
5. Only after acceptance, separately bump the launcher version and publish an
   immutable release through the existing reviewed flow. Do not overwrite 1.0.4
   or activate this candidate on the stable feed while either provider is unavailable.

Tests: `dotnet run --project tests/Launcher.Tests.csproj -- --directory-only`
runs the offline directory contracts on .NET 8. The normal Windows suite includes
these tests plus the existing updater, native-client and executable replacement
checks. All HTTP/DNS/game-process effects in the directory suite are injected;
there is no scanning, real game connection, credential use or production mutation.

The shared `tests/fixtures/server-directory-unicode.json` and
`tests/fixtures/server-directory-vzg.json` files also exercise Civilizationbot's
production projection. Fixture timestamps and ports are synthetic test data,
never deployment configuration or evidence that a public server is online.
