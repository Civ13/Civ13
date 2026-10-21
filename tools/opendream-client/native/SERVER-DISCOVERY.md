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
share one three-second deadline per eligible candidate, so two parallel eligible
candidates take roughly three seconds plus local scheduling/parsing overhead. Each remaining
address receives a fair share of the remaining time; sockets close before the
next attempt. No application DNS cache, startup IP pin or unchecked second DNS
lookup is used. Back/Refresh are offered after the bounded sweep settles.
Connection failure before a Topic write can try the next address. Once a Topic
has been reserved/written, a failed or invalid response cannot cause another
immediate Topic write to an alternative address.

## Shared request spacing and responsive waiting

Real network probes use `TopicPacer.Shared` at the fixed per-account directory
`%LOCALAPPDATA%/Civ13/status-requests`, independent of installation root or
`--root`. It is a cooperative limiter for this launcher's Windows account, not
a security boundary against users editing their own files or other programs.
Other computers behind shared NAT and unrelated monitoring cannot be coordinated
by these local files.

An exclusive local file lock protects at most four candidate records and their
validated public IPv4 aliases. Canonical target and overlapping addresses on the
same configured port share eligibility. Addresses are bookkeeping only; they
never supply a connection destination or permanent IP pin. Before writing any
Topic bytes, the request durably reserves 137 seconds: 130 seconds of spacing,
the three-second IO window and the full four-second swing of permitted clock
slew. Schema 2 also persists the system-wide `Environment.TickCount64` value
at reservation time. New processes keep only the true remaining interval; fresh
or expired anchored history adds no startup wait. A positive uptime difference
remains conservative across reboot because the new uptime alone exceeds that
difference. If uptime is lower than the saved anchor, eligibility requires the
first 133 seconds of the new boot, without restarting that wait on each launch.
See [Microsoft's TickCount64 contract](https://learn.microsoft.com/en-us/dotnet/api/system.environment.tickcount64?view=net-8.0).
The launcher remains pinned to .NET 8; changing clock semantics in a future
runtime requires rechecking this persisted timing contract.

Schema 1 (1.0.5) has only wall timestamps and no result cache. For those matching
endpoints only, retain the existing 133-second process-monotonic migration guard
and any longer valid wall reservation; a new request replaces that entry with
schema 2. Do not invent cached responses or clear old history. Older 1.0.5
instances fail closed when they encounter schema 2 instead of ignoring it.
Wall-clock steps outside the two-second monotonic comparison tolerance still
pause checks within a process. This fixed anchor cannot absorb gradual clock
drift through repeated early checks. Waiting cannot establish server game-time
advancement or clear a ban.

Validated success/failure results are written under the same lock/state, tied to
the reservation's unique request ID. Late completion cannot replace a newer
reservation or result. Success caches store only bounded validated metadata and
the original check timestamp; they never hold an IP destination or verified
launch token. Failure caches report an unsuccessful last check, not current
offline status. Unknown/pending results remain unknown. Cache display is limited
to ten minutes, labeled with age, and requires a new full prejoin validation even
if selected during cooldown. Cache-write contention cannot replace an established
verification failure with a waiting selection. Successful-response cache lock
contention can omit display caching while preserving the freshly verified result;
invalid storage still pauses checks. No cached result skips pacing,
DNS, identity validation or dispatch freshness checks.

State is bounded to 32 KiB, schema checked, flushed and replaced atomically in the
same directory. Missing/inconsistent, corrupt, locked, inaccessible or linked
state never resets the allowance. Contention returns a short local deferral;
invalid storage pauses checks and is distinguished from remote unreachability.
No ACL, account, credentials, firewall, DNS or server setting is changed.

Spacing is checked before DNS and again immediately before a wire write to
account for newly resolved aliases. A deferral exits and disposes the attempt;
it never sleeps inside the three-second IO budget. Discovery reports waiting
candidates separately.

After a successful reservation, a malformed response, identity mismatch, read
failure or cancellation ends verification immediately without dialing another
address. The failed request retains its reservation and is reported as failed
verification, rather than disguising the failure as a wait on the next address.
If a selected join is deferred, the menu retains only
the selected identity for comparison, prints remaining seconds, and accepts J
to explicitly recheck or B to cancel. No background timer or delayed send exists.
An early J is a local check, not another Topic. An eligible J obtains fresh DNS,
fresh status and a new literal token immediately before dispatch. Old snapshots
or expired 15-second tokens never become permission to join.

These conservative wall-time margins cannot prove 120 game seconds elapsed if
the server pauses or lags. The checked-in game gate can retain an already banned
raw address for the world instance. Pacing cannot clear that ban, and changing
source ports/egress or deleting local timing state is not a recovery procedure.
The matching Europe diary records bans, including the Desktop public source,
without timestamps; exact launcher-event correlation and loaded-build provenance
remain unverified. Do not query that source again until the runtime owner
coordinates normal eligibility. Live prejoin and genuine join acceptance remain
blocked; all pacing validation here is offline.

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
If a prejoin check or client start fails, the menu invalidates that selection and
waits for explicit Refresh/Back. It never automatically repeats the discovery
sweep after that failure. This avoids an unintended burst of Topic requests;
it does not bypass server query limits or guarantee a temporarily refused query
will recover. The checked-in game source has a non-whitelisted Topic cooldown,
but the running server's configuration and any live ban must be verified separately.

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
configured eligible read-only status queries and prints safe projected metadata; it never
installs or launches a client. No live query runs in normal offline CI tests.
The diagnostic does not perform an immediate prejoin recheck. Do not run it from
a known blocked source. Pacing tests use injected clocks/transports, separate
local processes, real lock/state files and supported symlink negative controls;
unsupported link creation is reported as skipped without changing permissions.

Build with the existing `Build.ps1` and run the complete tests against its EXE.
Require exact-head Windows CI, independent review, current public status and a
genuine join using the existing authorized client before publishing a separately
versioned immutable release through the existing workflow. Queries and process
construction alone do not prove gameplay. Stable release/feed remain 1.0.4 until
that acceptance and official release pipeline succeed. No game/bot restart or
additional game installation is required for status verification.
