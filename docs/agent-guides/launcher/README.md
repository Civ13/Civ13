# Launcher: scoped agent notes

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

<!-- 2026-10-21: direct BYOND status discovery -->
Public native menus probe only the configured Civ13.com and ValZarGaming hostnames
on ports 1714 and 1715. These are candidates, never an online assertion or a mode
mapping. No HTTPS server directory, backend deployment, port ranges or arbitrary
public --server-port override is involved. Resolve the entire A-answer set and
reject any nonpublic member before opening sockets. Try literals sequentially
within one three-second total deadline per candidate, with fair remaining slices.
Each menu refresh checks only its provider's two candidates concurrently. Valid
integer players=0 is online; optional metadata is unknown when absent and rejects
the response when malformed. Before joining, validate fresh DNS against the exact
respondent. A <=60-second UTC/monotonic process-local response proof can avoid a
duplicate Topic request during cooldown; never reconstruct it from disk cache.
Reject changed or missing selected map/mode/round identity on new status queries;
bounded response reuse cannot observe a round change during that short window. Bind verified
status, literal and configured port together, validate freshness at dispatch,
and launch only the verified BYOND client. Never add a permanent IP pin or reuse
this query for OpenDream. Source merge does not activate the launcher feed;
exact-head packaging/CI, independent review and a genuine public join gate release.
See tools/opendream-client/native/SERVER-DISCOVERY.md.
Public Topic writes use the fixed per-account status-requests lock/state,
independent of --root. Reserve before writing, retain failed reservations and
correlate validated IP aliases plus configured port. Spacing defers locally;
never sleep inside the three-second IO budget or silently retry after a write.
The 137-second reservation covers 130 seconds plus IO/clock margins; new instances
reuse system-wide monotonic anchors and cached result/age without adding another
startup wait. Legacy 1.0.5 wall-only history retains the 133-second migration guard
for its matching endpoint until its next reservation. A lower uptime waits only
through the new boot's first 133 seconds. Schema 2 caches bounded validated
metadata, never launch tokens; late results are tied to reservation IDs. Older
1.0.5 instances fail closed on schema 2. Clock/state/link failures pause locally. J explicitly rechecks a deferred selection; B cancels with no
background callback. Joining needs fresh safe DNS and an original-age recent proof
or one eligible new status response. Never extend status age or DNS token life;
recheck original monotonic and UTC60-second expiry at dispatch. Persisted cache
is display-only after process restart. See SERVER-DISCOVERY.md for join controls.
Wall time cannot prove game-time advancement or clear a server ban. Do not probe
the known banned Desktop source until owner-coordinated normal eligibility.

<!-- 2026-10-24: offline launcher social contracts -->
tools/opendream-client/native/Social is inert; production Main stays unwired.
tests/SocialContracts runs injected adapters/clocks/discovery/dispatch only,
separate from updater replacement tests. Reuse NativeStart and existing proofs;
dispatch is not connected gameplay or shard-travel evidence. See its README.
Keep player presence/native callbacks separate from DiscordPHP backend APIs.
SDK linking/distribution and native acceptance remain separate gates. Application
profiles are explicit per host; no application ID is a universal default.
PumpedSocialClient needs one explicit worker pump; Accepted/ClearIssued are local
evidence, not Discord UI/remote cleanup proof. No native transport is supplied;
CompanionPresenceTransport adds original bounded framing over an injected channel;
no helper, OS pipe, SDK loader or startup composition is supplied. See
SOCIAL-SDK-COMPANION.md in the native launcher directory for the peer obligations.
Before an isolated .NET CLI home's first use, set
DOTNET_GENERATE_ASPNET_CERTIFICATE=false to avoid automatic development-cert setup.

<!-- 2026-10-15: native graceful shutdown boundary -->
Native BYOND `del(world)` can return before process exit. Yield before declaring
shutdown failure, or transaction cleanup can erase the published recovery intent.
The lifecycle disk fixture checks the intent after exit; its `shutdown-return`
negative control reproduces the old immediate cleanup.

<!-- 2026-10-19: bounded launcher transport retries -->
Launcher retry tests use injected HTTP handlers, never BYOND/accounts. Retry only
classified resets/timeouts with finite attempts and an overall body-read budget;
certificate/auth failures, untrusted redirects and bad hashes remain fail-closed.
Delete only a failed attempt's newly created staged file, never a pre-existing
path. Preserve TLS validation and redact errors. Proxy IsBypassed(false) alone
does not prove traffic used a proxy. Source changes do not activate a release.

<!-- 2026-10-14: native launcher packaging -->
`tools/opendream-client/native/Build.ps1` builds the single-file self-contained
Windows x64 launcher. Its offline console tests cover mock updates plus actual
EXE replacement after parent exit and BYOND prerequisite adapters, without accounts
or a game. Release publication builds the exact tag and verifies immutable asset
readback before advancing the separate native feed; prereleases do not activate it.
Preserve the existing client channel and distinguish package integrity/BYOND setup
from identity/gameplay acceptance. Never silently accept installer licenses.
