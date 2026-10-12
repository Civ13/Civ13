# Extraction status adapter draft

Parser and launcher ownership agreement is pending through the extraction
coordinator. This document describes proposed fields, not an implemented or
accepted endpoint. Native execution and live probes remain on hold.

The existing `status` Topic returns an unversioned count. The `players` Topic
returns `no.`. `serverdata.txt` contains semicolon-delimited display text,
realtime and a client list; its writer deletes and recreates it every 100 ticks.
It is not an atomic versioned snapshot or a readiness receipt.

Proposed read-only Topic `extraction_status` returns JSON with:

| Field | Meaning |
| --- | --- |
| schema | `civ13.status.v1` |
| instance_id | Unique boot identity, stable within this world instance |
| build_id | Trusted configured build identity, otherwise null |
| map_id / map_name | Current map identity, nullable while loading |
| generated_at | Decimal BYOND realtime, deciseconds since 2000-01-01 UTC |
| ready | Explicit launcher/map-completion state, not response availability |
| player_count | Actual connected client count |
| players | At most 64 canonical ckeys |
| truncated | True when the list omits connected players |

Keep the existing Topic dispatcher, whitelist and cooldown. Do not globally
relax legacy address checks. Player identity visibility and any additional
authorization must be agreed before enabling the endpoint. Do not infer build
identity from a branch name or readiness from a listening port.

The parser must reject malformed, stale or future timestamps and inconsistent
counts. A fresh ready response with zero players is a valid empty server.
An unreachable or stale response means offline/unknown, never zero players.
The accepted freshness budget and clock-skew tolerance must be shared by game
and bot tests. Truncated lists must not be treated as complete membership.

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
