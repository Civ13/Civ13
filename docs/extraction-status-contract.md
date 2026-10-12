# Extraction status adapter draft

The coordinator approved the strict wire and access policy. Launcher binding
and poll cadence remain pending. This document describes fields, not an implemented or
accepted endpoint. Native execution and live probes remain on hold.

The existing `status` Topic returns an unversioned count. The `players` Topic
returns `no.`. `serverdata.txt` contains semicolon-delimited display text,
realtime and a client list; its writer deletes and recreates it every 100 ticks.
It is not an atomic versioned snapshot or a readiness receipt.

Proposed read-only Topic `extraction_status` returns JSON with:

| Field | Meaning |
| --- | --- |
| schema | `civ13.status.v1` |
| instance_id | Nonempty opaque ASCII boot identity, at most 80 bytes |
| build_id | Trusted configured identity at most 80 bytes, otherwise null |
| map_id / map_name | Nullable UTF-8 map identity, at most 128 bytes per field |
| generated_at | Canonical nonnegative integer string, BYOND deciseconds since 2000-01-01 UTC |
| ready | Explicit launcher/map-completion state, not response availability |
| player_count | Actual integer client count, proposed accepted range 0-65535 |
| players | At most 64 unique ASCII canonical ckeys, each 1-64 bytes |
| truncated | Strict boolean; true when the list omits connected players |

Keep the existing Topic dispatcher, whitelist and cooldown. Do not globally
relax legacy address checks. The adapter is disabled by default and requires a
read-only capability. Player lists require authenticated scoped authorization
independent of IP whitelisting. Public count-only responses require an explicit
configured policy. Reject malformed capabilities and unknown schemas; never log
capability secrets. Bind the caller to its trusted target/profile/server identity.
Display ckeys are not authentication verifiers. Do not infer build
identity from a branch name or readiness from a listening port.

The parser must reject malformed, stale or future timestamps and inconsistent
counts. A fresh ready response with zero players is a valid empty server.
An unreachable or stale response means offline/unknown, never zero players.
The accepted freshness budget and clock-skew tolerance must be shared by game
and bot tests. Truncated lists must not be treated as complete membership.

The bot proposal uses overflow-checked conversion to Unix milliseconds:
`generated_at * 100 + 946684800000`, with an injected clock. Proposed defaults
are 30 seconds maximum age and 5 seconds future tolerance; configuration caps
are 120 seconds age and 5 seconds future tolerance. These values await agreement
with actual poll cadence. Require strict booleans, integer count and no duplicate
ckeys. An untruncated list must match count exactly; a truncated list may be
shorter. Never clamp an out-of-range count into a valid response.

Readiness must invalidate before map replacement or shutdown and remain false
through initialization, recovery or a failed start. Restore it only after the
launcher-owned completion boundary for the reported instance/build/map. A new
boot receives a new opaque identity; the legacy time-derived `game_id` alone
does not establish uniqueness. Boot entropy does not authenticate ownership.
Prefer the trusted controller launch identity. Null or unknown build identity
cannot prove readiness for a requested revision. A truncated list cannot prove
player absence. Public count responses must not expose private player identities.

Host lifecycle operations need separate update/build/start/stop/map receipts:
operation ID, requested revision/map, owned process or instance identity,
pending/failed/completed state and bounded diagnostic code. Start completes only
after matching instance/build/map readiness; stop only after the owned process
exits. Scheduling a shell command or timer is merely pending. The coordinator
must assign the existing launcher owner before these controls are implemented.

Acceptance uses injected clocks, clients, readiness and process adapters:
empty/loading/stale/future/malformed/truncated responses, count consistency,
ownership mismatches, failed builds, start timeout and confirmed stop. Preserve
ordinary Topic behavior. Mock acceptance does not establish live hosting.

Include timestamp overflow and epoch conversion, unauthorized privileged queries,
wrong instance/build/map and transition races. Do not enable the adapter before
the frozen controller API and shared poll cadence are agreed.
