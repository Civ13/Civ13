# Direct BYOND server status (unreleased)

## Scope and configured targets

The two menu groups query these explicit candidates, inherited from the previous
native catalog, without assuming a game mode or online state from a port:

| Menu | Host | Candidate TCP game ports |
| --- | --- | --- |
| Civ13.com | civ13.com | 1714, 1715 |
| ValZarGaming | valzargaming.com | 1714, 1715 |

`ServerCatalog.Candidates` owns this finite configuration. No port ranges,
third-party hosts, server-supplied endpoints, automatic port scans or public
`--server-port` override are accepted. An unused candidate simply fails status.
Adding/changing ports requires a reviewed catalog update. This discovers which
known endpoints answer; it cannot discover arbitrary hosts or unknown ports.

There is no HTTP/HTTPS server-list request in discovery or joining. The earlier
PR design's civ13.com well-known directory and companion Civilizationbot PR #20
are unnecessary for this launcher path. Neither that backend nor the prepared
operator package should be deployed for this revision. Existing HTTPS client,
launcher update and prerequisite downloads keep their normal trust checks.

## Status and availability

`ServerDiscovery` queries only the selected provider's two candidates concurrently
(maximum two active sockets). `ByondStatus` resolves the approved hostname's A
records anew for each candidate, validates every answer before opening a socket,
and tries deduplicated public IPv4 literals sequentially. DNS/connect/write/read
share one three-second deadline per candidate, so two parallel candidates take
roughly three seconds plus local scheduling/parsing overhead. Each remaining
address receives a fair share of the remaining time; sockets close before the
next attempt. No application DNS cache, startup IP pin or unchecked second DNS
lookup is used. Back/Refresh are offered after the bounded sweep settles.

The fixed read-only BYOND TCP Topic query is `?status=1&format=json`. A reachable
TCP port alone is insufficient. The response must be a bounded BYOND string frame
and UTF-8 JSON object with an integer `players` in 0..10000. Zero is a valid online
empty world. Missing player count, malformed service response and unreachable
endpoint are unverified, never displayed as an empty online server.

Map, mode, epoch, round ID and elapsed round time are optional. Missing/blank
text displays as unavailable. Present malformed fields reject the response;
no string/boolean/null conversion invents metadata. Round IDs/epochs may be
bounded strings or signed 64-bit integers; elapsed ticks must be finite,
nonnegative and at most int.MaxValue. Display text is byte-bounded strict UTF-8
with control/format/surrogate/line-separator characters rejected. Duplicate JSON
properties are rejected recursively. Packet size is at most 65,536 bytes and
JSON depth at most 16. Raw status, player identities and address details from
status are not projected into the menu.

## Joining and identity limits

Selecting a displayed service performs another direct query of that same catalog
candidate, even after a long menu pause. Previously observed nonempty map, mode
and round ID must still match and cannot disappear. Player counts, elapsed time
and epoch may change naturally. If identity changes, refresh and select again.
When optional identity was absent, it cannot authenticate a round; BYOND status
is a consistency/availability check, not cryptographic server authentication.

The successful result binds status, public literal and configured port together.
Dispatch verifies catalog membership, status age <=60 seconds, the monotonic
literal lifetime <=15 seconds and the required verified BYOND client, then passes
one argument `byond://<verified-IP>:<configured-port>` to DreamSeeker. No DNS lookup
occurs in the client URL. OpenDream remains a separate explicit operator path;
this JSON status contract is BYOND-specific.

The conservative IPv4 exclusions follow the IANA special-purpose registries:
https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry.xhtml
https://www.iana.org/assignments/multicast-addresses/multicast-addresses.xhtml

## Verification and release

Offline production-code tests cover configured scope, framing, strict metadata,
empty/offline distinction, DNS safety/failover/deadlines, prejoin identity and
literal/port retention, menu choices, update and actual executable replacement.
Run `dotnet run --project tests/Launcher.Tests.csproj -- --discovery-only` for
focused injected controls. `--probe-public` explicitly performs only the four
configured read-only status queries and prints safe projected metadata; it never
installs or launches a client. No live query runs in normal offline CI tests.

Build with the existing `Build.ps1` and run the complete tests against its EXE.
Require exact-head Windows CI, independent review, current public status and a
genuine join using the existing authorized client before publishing a separately
versioned immutable release through the existing workflow. Queries and process
construction alone do not prove gameplay. Stable release/feed remain 1.0.4 until
that acceptance and official release pipeline succeed. No game/bot restart or
additional game installation is required for status verification.
