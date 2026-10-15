# Extraction OpenDream account and persistence audit

This source audit follows the October 13 human selection of OpenDream for
connected playtesting. It is based on extraction source head
`83ee43c63b18af67d2e911a5baa6f49004721e4f`. No OpenDream compiler, server or
client was executed. The checked-in extraction launcher remains BYOND-specific.

## Account ownership path

`code/modules/client/client_procs.dm` accepts client connections labeled
`seeker` or `web`, checks `byond_version` against 512 and then 513, and indexes
the client directory and preferences by `ckey`. These checks have no local
`OPENDREAM` alternative. The selected OpenDream package must establish its
actual connection/version fields and authenticated key behavior; source alone
does not establish whether those checks accept or reject that package.

`code/game/mob/new_player/login.dm` constructs a mind using `key`; its
`OPENDREAM` branch loads the pregame interface. Character creation in
`code/game/mob/new_player/new_player.dm` transfers `key` to the new human.
`code/game/jobs/job_controller.dm` invokes extraction admission after relocation
and rejects a character when admission fails. None of these steps establishes
a mapping from launcher credentials to an authenticated extraction owner.

`code/modules/1713/extraction/mode.dm` uses `H.client.ckey` as `identity(H)`.
An owned operation also requires the active session's exact body and matching
owner. The house terminal checks `H.client.ckey` directly. In
`transactions.dm`, one service admits at most one active session per owner.
`account_store.dm` requires a canonical `ckey` string of 1-64 characters and
rejects names beginning with `guest`; this is a syntax gate, not authentication.

Two testers therefore need distinct, authenticated, non-guest canonical ckeys
that remain stable across reconnect and server restart. Administrative identity
or a web login by itself does not establish this contract. Aliases that normalize
to one ckey must not be treated as separate extraction accounts. One authoritative
server must own the account directory; the session dictionary is not a lock
between independent servers.

## Separate durable safehouses

Admission selects the first available private marker, opens the owner's durable
account, commits first-time starter issuance, validates the stored equipment
graph, then reconstructs actual stash and garage objects. Sixteen private rooms
are a physical admission limit, separate from the 32-participant limit.

Durable stash, credits, upgrades and garage belong to the canonical account.
The ordinary room marker is a runtime allocation and need not retain the same
coordinates after reconnect. Room movement and storage access require the bound
session and owner. `release()` checkpoints a home session before retiring its
physical equipment, clearing the marker session and closing the account session.
Disconnect handling waits two minutes before releasing a home or forfeiting a
raid. Those timing and reconnect paths need connected acceptance.

`home_replica.dm` separately retains durable replica owner/revision/digest on
markers. Ordinary admission refuses both replica-bound accounts and fully or
partially bound markers. The shared generation restore/retirement handoff remains
unimplemented and under serializer ownership; it is not established by ordinary
account reconnect behavior.

## Engine and persistence contracts still unresolved

| Source path | Contract needed from the selected package |
| --- | --- |
| `code/__byond_version_compat.dm`, `civ13.dme` | Compiler compatibility with the 516.1681 source gate, actual OpenDream compiler/server/client versions and artifact hashes. No checked-in engine version pin was identified. |
| `code/modules/client/client_procs.dm` | Accepted connection/version fields, authenticated `key`/`ckey`, guest rejection, stable identities and alias handling. |
| `code/modules/1713/extraction/account_store.dm` | `text2file` appending the expected newline, exact `file2text` readback, `fcopy`/`fdel`, `md5`, JSON list/scalar behavior and interrupted two-slot journal recovery. The digest includes the durable newline. |
| `code/__defines/_rust_g.dm` | Actual external-call implementation and optional file-I/O overrides in the chosen package. Macro presence does not prove compatible native exports. |
| `code/modules/1713/extraction/equipment.dm`, `garage.dm` | Actual constructors, nested item identity, codec round trips and paid vehicle reconstruction under OpenDream. |
| `code/modules/persistence/` | Separate serializer-owned native world-save compatibility and generation handoff. Extraction JSON journals do not prove cross-engine native savefile compatibility. |
| `tests/extraction/run-playable.ps1` | Existing BYOND verification path only. An OpenDream package/launcher and isolated account root must come from the launcher owner. |

## Prepared verification and limits

`tests/extraction/mode_probe.dm` injects identity into actual human bodies. Its
existing two-owner room, foreign movement, secure storage and account reload
vectors exercise extraction logic, not engine authentication. New source vectors
reject a duplicate canonical owner without a second session or starter checkpoint,
and reject session operations after the injected identity changes to the other
owner. They restore the original identities before continuing the fixture.
These additions are uncompiled and unrun during the execution hold.

`tests/extraction/store_probe.dm` already covers invalid/guest owners,
cross-account state isolation, restart slot selection and interrupted journal
recovery. These existing vectors should run under the chosen OpenDream engine in
temporary storage before claiming compatibility. A separate BYOND run establishes
only BYOND compatibility.

Connected acceptance must record two authenticated client identities; distinct
rooms and account directories; foreign movement/storage/terminal refusal;
duplicate-owner admission refusal; one paid/starter graph per owner; and durable
independent balances, upgrades and nested items after reconnect and isolated
server restart. Include logout/reconnect timing, raid loss/extraction and actual
terminal UI. Record exact source, engine, client, map and artifact provenance.
Do not infer these results from the injected fixture, web authentication, source
inspection, a BYOND build or successful journal metadata checks.
