# Gateway verified-access snapshots

A Persistence or Barracks/Battle TDM group with a dedicated relay gateway can opt in to one
durable, gateway-owned version of the normal approved and job-whitelist lists.
These are the existing Discord-linked lists, not any other allowlist. The
default is unchanged. This slice provides the private publication and game
reader; it does not switch CivilizationBot's deployed writer.

## Publication contract

A trusted gateway-side process submits one JSON object containing exactly
`approved` and `whitelist`, the complete canonical projections for the same
capture (including trailing newlines). A single newline represents an
explicitly authorized empty list; missing or truncated text is not empty.
The gateway host's `shard_group.py --config <group> publish-verified-access`
accepts this object on standard input. It reports only the new revision and
whether publication changed; never send raw list contents in arguments, logs,
chat or Topic requests. It accepts no caller-provided destination or region.
Use a fresh, complete verification/role capture and keep the bot's existing
authentication and empty-list safeguards.

With `gateway_verified_access_inbox: true` (separately opt-in), only the
protected gateway inbox is accepted: `front-door/access-inbox/proposal.json`.
[CivilizationBot #127](https://github.com/Valgorithms/Civilizationbot/pull/127) supplies the complete pair plus the exact `group` ID;
the producer cannot choose paths or allocate revisions. The existing
host supervision checks this fixed inbox on its normal cadence. A local
operator can also check it using `consume-verified-access`. A missing
proposal does not revoke lists; an explicitly empty validated pair does.
The direct stdin publisher refuses to run in inbox mode.

Run only one authorized bot producer per group. Give it write access to
its own private inbox, not to the gateway SQL directory. Do not roll back
an inbox or authority file. TDM needs a configured dedicated gateway;
the existing two-world configuration and its policy are unchanged by
default. Approved access and TDM job whitelisting retain their original
per-world enablement rules.

The publisher locks the sequence, validates both halves before replacing
anything, and writes one atomic, revisioned file under the persistent
`front-door/SQL` directory. A no-op leaves the revision alone. File ownership
is the authorization boundary, not a claim inside a JSON object: the gateway
publisher must have the only writer access, the game consumers need read
access, and the enclosing directory must not be publicly exposed. On POSIX,
use a protected, setgid directory with the selected reader group; the file
is replaced as owner-writable, group-readable. On Windows, use the
corresponding inherited directory ACL. An
installation that runs all processes under one unrestricted account cannot
provide operating-system isolation between them. No new network control,
token, public status fields, or world-to-world calls are introduced.

Replacing the bundle is the gateway's reload notice. Running worlds watch
the fixed authority path and refresh within five seconds under ordinary tick
conditions, with retry on later polls. A world reads the current authority
snapshot before it marks either list ready after startup. Incoming player
connections also reread it before Login, including a connection that wakes
a frozen world without advancing the server's tick clock. On unreadable
content, wrong group, malformed data, or a rollback within the current
process, it refuses protected grants rather than reading a region's legacy
list. Standalone/non-opted-in worlds retain the current legacy readers.

## Rollout boundaries

Do not enable `gateway_verified_access` until the gateway's trusted publisher
(including the CivilizationBot-side integration) is ready, its private
directory ownership has been reviewed, and the intended first complete
snapshot can be supplied. Use an approved staged configuration procedure to
generate the per-world setting and build the matching readers. Do not change
the option on live worlds during a partial rollout. Keep the gateway's
authority snapshot and current revision across restoration, and do not
restore an older copy independently of the authority.

This does not edit identities, bans, admin ranks, or role policy. Ban
durability still belongs to the transfer coordinator's shared player records;
the gateway's existing `bans.txt` projection remains the bot's compatibility
view. It does not add bot command routing, change who can ban or unban, or
rework existing ban startup admission.
