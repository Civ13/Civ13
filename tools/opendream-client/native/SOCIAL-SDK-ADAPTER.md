# Launcher presence adapter

This milestone implements the SDK-independent adapter behind the contracts merged
in #3305. A subsequent [native core/backend](companion/README.md) supplies the
C++ SDK C-ABI mapping with fake-driven tests. Production startup is
still unwired; normal BYOND/DreamSeeker play does not depend on the launcher,
Discord, account linking, presence or microphone permission.

## Implemented behavior

PumpedSocialClient implements ISocialClient with one pending update and one
in-flight transport operation. It lazily calls an explicitly injected transport
factory only for an admitted, fresh update. Construction, default-disabled pumps,
and enabling without an update perform no transport initialization. It creates
no worker, timer, process, SDK client or socket by itself.

The future launcher/companion owner must pump this adapter on one independent
worker thread. Construction, publish, callback pumping, clear and disposal all
run on that thread, outside the producer admission lock. Producer/UI methods
enqueue bounded state; they never call the transport. Console input must not
stop pumping. No work belongs in DreamDaemon's simulation loop.

Updates coalesce to the latest revision. Generation changes synchronously settle
obsolete application requests and fence their results. An already invoked native
update remains tracked until its callback settles or the callback budget expires;
a newer update cannot race ahead of it. Duplicate or late old callbacks cannot
change the adapter's current state. Callbacks capture a bounded request rather
than the adapter or native client.

Only the fixed launcher Details/State text is mapped. No player identity, account,
party size, shard/body ownership, coordinates, inventory or progression is inferred.
Dispatch presence keeps the original 15-second monotonic lifetime. At the first
pump observing expiry the adapter issues clear rather than renewing that lifetime.
The callback must also be observed before its independent monotonic timeout
(default five seconds, configurable up to thirty). Clock reversal refuses work.

Clear is terminal for its generation, including when its caller token is cancelled.
The pump waits for an old native update, issues clear and closes that session's
transport. A new generation may explicitly create a fresh session after clean
opt-out. StopAsync rejects new work and settles when the owner finishes pumping
cleanup. Do not wait for optional social cleanup as a prerequisite to playing.

Snapshot is sanitized local evidence: Accepted means the active callback reported
success; it does not prove Discord profile rendering. ClearIssued means a void
clear request was issued, not that Discord acknowledged remote removal. Method
tasks mean settled, including superseded/cancelled/degraded requests, rather than
remote success. The snapshot contains enums/counters, not raw SDK errors or paths.

Missing dependencies, unavailable Discord, invalid callbacks, exceptions or missed
deadlines quarantine the adapter. Pending tasks settle, cleanup is attempted once
and no automatic reconnect, request retry or replacement client is started. A
failed/uncertain clear is not retried. Native timeouts cannot prove remote cleanup.
Pump scheduling cannot preempt a blocking DLL call or contain a native crash;
that remains a reason to evaluate a narrowly scoped companion process.

## Native binding and release gates

IDiscordPresenceTransport is an application seam, not an official managed binding
or a declaration of native exports. The follow-up CompanionPresenceTransport
implements an original bounded protocol over an injected channel; it supplies no
OS channel, process or SDK binding. There is no default composition, dynamic
loader, P/Invoke, token flow, provisional account or vendor dependency. See
[the companion contract](SOCIAL-SDK-COMPANION.md).

Read-only package inspection now verified standalone SDK 1.10.19337, its C/C++
headers and Windows-x64 DLL/import library. The owner-confirmed application
string `1562126764849897544` is VZGCivilizationbot for ValZarGaming hosts, with
owner/UI SDK-enablement evidence. It is not a universal Civ13 default or proof
of production communications approval. Vendor code is not distributed here.

The next native slice still requires:

- A reviewed use/packaging record for the pinned package, matching release
  headers/libraries and notices; no SDK payload is bundled in this patch.
- A reviewed binding path for the .NET 8 x64 launcher: approved compatible managed
  bindings or a small C++20 bridge/companion built against those exact headers.
- Explicit per-host application configuration, never inferred from bot presence.
- A licensing/distribution decision for the SDK alongside this repository's
  license, and separate authorization before native loading or live calls.

The initial adapter milestone lacked package/application inputs; those findings
are superseded above. No unofficial legacy RPC package or invented native ABI
is substituted by the companion protocol.
The launcher/companion is x64; a BYOND 516.1688 DreamDaemon is x86. No SDK DLL is
loaded into DreamDaemon and no cross-bitness in-process call is proposed. Any
later game-context bridge must be small, versioned and validated, carrying only
approved session/context observations while servers retain gameplay authority.

## Official documentation checked 2026-10-25

- [SDK reference](https://discord.com/developers/docs/social-sdk/index.html):
  C++ library, generated Unity/Unreal integrations, raw data without game UI;
  communications require application authorization.
- [Client reference](https://discord.com/developers/docs/social-sdk/classdiscordpp_1_1Client.html):
  UpdateRichPresence takes a completion callback; ClearRichPresence is void.
  SetApplicationId identifies unauthenticated RPC presence/invites. A future
  transport maps these operations and RunCallbacks; these are not C ABI names.
- [Presence guide](https://docs.discord.com/developers/discord-social-sdk/development-guides/setting-rich-presence):
  desktop RPC presence can avoid OAuth when an application ID and running Discord
  client are available. This is not evidence that either is configured here.
- [Compatibility](https://docs.discord.com/developers/discord-social-sdk/core-concepts/platform-compatibility):
  Windows x64 10+ and standalone C++20+ are supported. Unity C# support does not
  establish standalone .NET binding/package compatibility.
- [Release notes](https://discord.com/developers/docs/social-sdk/release_notes.html):
  latest listed patch is 1.10.19337 (2026-09-01). Version 1.10.18369 fixes C#/native
  bool marshaling. Neither a documentation-generator footer nor a cached legacy
  package identifies the approved downloadable SDK build.
- [Communications access](https://docs.discord.com/developers/discord-social-sdk/core-concepts/communication-features):
  development communications have per-application caps. Production increases
  require the application's Comms Access review and supporting feature/UX evidence.
  No communication grant, account flow, voice or microphone action is implemented.
- [SDK terms](https://support-dev.discord.com/hc/en-us/articles/30225844245271-Discord-Social-SDK-Terms):
  SDK access/distribution is governed by separate terms. No acceptance or licensing
  determination is supplied by this source-only adapter.

## Acceptance and remaining work

The SocialContracts runner exercises the real adapter with fake transport effects,
clock advancement and producer/callback threads. It covers lazy initialization,
bounded coalescing, one in-flight operation, generation/revision fences, expiry,
late/duplicate callbacks, clear/stop ordering, opt-out cancellation, loader failure,
transport exceptions, no automatic retry, reentrant producers and pump ownership.
The ordinary manual browser path remains usable after optional adapter failure.
All transport calls in these tests are synthetic; they establish no native ABI,
DLL loading, Discord UI, authentication, live invite or microphone acceptance.

Next: review the implemented native core/backend, then supply a bounded private
process/channel host and review vendor linking/distribution and live acceptance.
Friends/account UI, invites through a real SDK callback, voice, media and game
context signaling remain later slices. No cosmetic launcher readiness option,
new game admission rule, spectator feed, release or deployment is added here.
