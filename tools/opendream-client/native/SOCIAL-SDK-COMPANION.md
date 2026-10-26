# Optional companion transport - source contracts

`CompanionPresenceTransport` implements the existing `IDiscordPresenceTransport`
over an injected nonblocking channel. Production startup remains unwired. No
channel implementation, child-process launcher, network listener, DLL loader,
credentials, authentication or live native execution is supplied here. The
[native companion core](companion/README.md) now implements the peer protocol and
an SDK C-ABI backend, compiled/tested using original fake SDK functions.
`PumpedSocialClient` retains generation/revision, expiry, callback deadline and
quarantine ownership; this transport adds bounded framing and peer lifecycle.

`CompanionProfile` requires an existing validated `GameTarget` and an explicit
canonical decimal uint64 application ID **as a string**. There is no default ID
or provider inheritance. The owner-confirmed `1562126764849897544` belongs to
VZGCivilizationbot for ValZarGaming servers. Independent Civ13 hosts need their
own explicit configuration. A profile is display context, never game admission.

## Version-one wire contract

A future x64 C++20 companion can consume these original application messages
through private inherited pipes, with one fresh channel per transport lifetime.
Do not expose a listener or reuse an old channel for a new peer. Writes admit a
complete frame atomically or admit zero bytes, with a bounded queue and prompt
return. Reads can fragment; zero means no bytes currently available.
EOF/failure sets `IsOpen=false`. No OS stream or peer authentication is supplied.

Every frame is at most 276 bytes. Its 20-byte header is:

| Offset | Bytes | Meaning |
| --- | --- | --- |
| 0 | 4 | ASCII `C13S` |
| 4 | 1 | Version `1` |
| 5 | 1 | Operation, below |
| 6 | 2 | Reserved, must be zero |
| 8 | 8 | Nonzero uint64 request ID, little endian |
| 16 | 4 | Payload byte count, little endian, at most 256 |

IDs increase without wrapping on the launcher side. Replies echo the operation
they complete. They cannot authorize game actions. The parser owns one fixed
276-byte buffer; each pump admits at most 16 reads. Invalid version, header,
length, reply schema or profile echo closes the channel without reconnecting.
Older completed result IDs are ignored; future IDs are rejected.

| Value | Operation | Direction and payload |
| --- | --- | --- |
| 1 | Hello | Launcher: port uint16 LE, provider byte length, ID byte length, provider ASCII, application ID ASCII |
| 2 | Ready | Peer: exact Hello ID and payload echo after accepting that profile |
| 3 | Publish | Launcher: Details byte length, State byte length, then their UTF-8 bytes |
| 4 | Result | Peer: exact Publish ID; one byte, 0=accepted, 1=unavailable, 2=failed |
| 5 | Clear | Launcher: empty payload; request only, no remote acknowledgement |
| 6 | Pulse | Launcher: empty payload; refresh peer lease |
| 7 | Stop | Launcher: empty payload; peer performs terminal cleanup |

Providers/ports are exactly the existing catalog candidates. Provider and ID
lengths must consume all Hello bytes. The peer must validate the canonical ID
and catalog target before creating its SDK client; it must never fetch an ID,
infer a bot identity, switch hosts, or accept a second Hello. Publish strings
are nonempty strict UTF-8 without controls, each at most 96 bytes. Their lengths
consume the complete payload. All fields are data, never commands or credentials.

The first Publish sends only Hello. No Publish crosses the channel before Ready
matches the entire profile. Ready at/after the three-second monotonic deadline
is rejected. Only one publication callback is retained, with no transport queue.
The outer adapter supplies publication deadlines and generation fences. A
successful Result means a local SDK callback, not Discord UI evidence.

The public transport fences Clear itself: during negotiation it synchronously
discards the queued activity and settles its callback as unavailable. Late Ready
can complete negotiation, but cannot publish that discarded activity; a later
explicit Publish is fresh work. During an outstanding physical Publish, Clear
closes the session with Clear/Stop and settles unavailable. Late Result/Ready
cannot revive it; another transport needs a fresh channel. After a settled
publication, Clear keeps the negotiated channel available for explicit new work.

Golden empty Stop frame, request ID 1:
`4331335301070000010000000000000000000000`

## Peer lifetime and native boundary

The peer independently pumps the SDK outside console/game simulation work.
After Hello, a fixed five-second monotonic lease applies. The launcher sends
Pulse at one-second pump intervals after negotiation. EOF, Stop, protocol error
or lease expiry must invalidate pending callbacks, issue best-effort clear,
release callback userdata according to the SDK free-callback contract and
destroy its one client. Cleanup must be idempotent; late native results must
not be written into a closed/new session. Do not retain game/server state.

Dispose attempts Clear once and Stop, closes the injected channel and settles
the retained callback. Backpressure or exceptions close without retry/reconnect.
Clear/Stop writes and local close cannot prove native/remote cleanup occurred;
keep `ClearIssued` semantics. The peer lease covers launcher crash/lost pumping.
The managed tests use a fake peer; the native core tests exercise the peer and
real binding with fake SDK functions. No production worker/process host exists.

The inspected SDK 1.10.19337 supplies C/C++ headers and x64 libraries, not a
standalone managed binding. The original C++20 backend now maps Publish to
Activity Details/State and `UpdateRichPresence`, pump `RunCallbacks`, translate
the result and use `ClearRichPresence`/client destruction during cleanup. One
owner must manage the global callback pump and userdata lifetimes. The x86
DreamDaemon must not load the x64 library. No SDK code is vendored here.

License/linking/distribution review, actual pipe/process implementation, vendor
binary ABI/runtime acceptance and separately authorized live presence remain
future work. Compilation against the real header with fake C functions verifies
binding declarations and ownership logic, not vendor binary/runtime behavior.
Account/friends/invites/voice are separate scopes. Ordinary BYOND/DreamSeeker
access and server verification remain independent of this profile and Discord.

## Offline evidence

SocialContracts drives the real transport over in-memory fragmented channels,
fixed clocks and a synthetic peer. It checks negotiation before publication,
profile precision/scope, golden bytes, invalid/oversized frames, callback mapping,
duplicate/stale replies, bounded work, timeout/clock reversal, backpressure/EOF,
no reconnect, owner thread, stop/lease cleanup and existing session integration.
Mock cleanup is not SDK/native acceptance. No process, socket, pipe or SDK opens.
