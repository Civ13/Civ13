# Optional launcher voice: implementation and acceptance

Tracking issue: [#5122](https://github.com/Civ13/Civ13/issues/5122).
Reviewed 2026-11-13 against master a504fad4828e50ce57ed6c2b7da45848b6f04e6c.

## Mandatory architecture: DiscordPHP

**DiscordPHP must be used for this implementation**, per the owner's explicit requirement. The intended server/control integration is PHP + DiscordPHP: identity/session coordination and Discord-facing orchestration through supported APIs. Do not substitute a separate bot library or Python Discord implementation.

The launcher/native Social SDK companion remains the proposed local microphone/audio boundary, not a replacement for DiscordPHP. DiscordPHP's bot voice support is not automatically a Social SDK player-voice binding. Before implementation, verify which lobby/auth/control operations DiscordPHP and Discord's supported API actually expose, identify any required DiscordPHP extension, and document the boundary. Verified DiscordPHP source already supplies Social SDK backend lobby APIs through LobbyRepository and SessionLobbyRepository. Player message operations use player OAuth, not bot impersonation. This is not a native client PCM/audio binding. Never put bot credentials in the player launcher.

## Long-term goal: move chat into the SDK

The owner's intended destination is to move all chat functionality into the SDK, not only voice. Treat this as a staged migration, not removal of current BYOND chat now. DiscordPHP remains mandatory for server/control integration. Inventory IC speech, whispers/shouts, language comprehension, radio/telephone, faction/OOC/admin channels, system notices and moderation before choosing a transport for each. Preserve formatting, accessibility, history, rate limits, block/report behavior and the distinction between private and public channels.

Before switching any channel, verify that the supported SDK/API can enforce its server-authoritative audience and permissions without trusting client-side filtering. An SDK lobby containing every player is not proof of confidential whispers or hidden-language delivery. Define which text is sent to Discord, retention/deletion and moderation responsibilities, and applicable platform-policy limits. Migrate one low-risk opt-in channel first with parity/failure tests; retain BYOND fallback until the replacement is demonstrated. Do not migrate private admin traffic or publish player conversations as a side effect of implementation.

## Scope and stopping rule

Deliver the existing native companion's missing host endpoint in a focused source
PR, then a separately reviewed opt-in push-to-talk prototype. Stop each slice at
its documented evidence boundary. Nothing here activates voice, changes a live
world or promises a production release over one weekend.

Ordinary DreamSeeker joining and text chat must continue when Discord is absent,
authorization is declined, a device fails or the companion exits. Never put SDK
pumping, microphone work, network waits or audio processing in DreamDaemon's tick
loop. Keep one owner for each branch and check current work before starting it.

## Existing implementation, not future claims

| Component | Current evidence | Missing acceptance |
| --- | --- | --- |
| DiscordPresence.cs and launcher GUI | Desktop RPC activity source and injected-stream tests | Not an audio transport |
| DiscordSignIn.cs | PKCE account sign-in, identify scope, single-use join tickets | No communications grant |
| Social/ | Bounded presence protocol and callback/lifetime contracts | Production SDK composition |
| companion/ | C++20 peer and presence C-ABI backend; fake SDK tests | Executable child endpoint and vendor runtime |
| WindowsCompanionFactory | Parent process/pipe source, fixed off, injected OS tests | Real Windows pipe/job/cancellation acceptance |
| Game proximity voice | Not implemented | Session binding, policy, transport and real-client audio |

The historical SOCIAL-SDK documents describe the separate SDK lane. Their
statement that account/GUI work is absent must not be read as a description of
the newer launcher-wide RPC and OAuth features. RPC presence does not demonstrate
SDK voice readiness.

## Dependency-ordered PR slices

### 1. Finish the companion host without enabling it

Reuse SOCIAL-SDK-HOSTING.md and SOCIAL-SDK-WINDOWS-PROVIDER.md; do not introduce a
second IPC design. Implement the child endpoint/entry point that consumes the
existing inherited handles and validated profile. Keep vendor binding isolated
from the original protocol core, and keep production activation off.

Acceptance: deterministic invalid-argument, fragmented I/O, bounded queues, EOF,
lease expiry, cancellation and cleanup checks. Windows runner integration must
prove handle ownership and child-only shutdown. SDK-free checks must not be
labelled vendor runtime acceptance. Record the precise package/header version
before adding a vendor-linked build; do not silently upgrade the historical pin.

### 2. Two-player opt-in push-to-talk

Add the minimum usable voice session through the SDK companion: explicit
opt-in, communications authorization, small lobby join/leave, device selection,
mute/deafen, volume and clear connection status. Default microphone transmission
off until the player deliberately enables and presses push-to-talk. Clear
transmit state on focus loss, key release, disconnect and cancellation. Do not
reuse the launcher's identify-only access token as evidence of communications
permission.

Cover declined consent, expired credentials, no microphone, changed device,
blocked participants, duplicate actions, stale callbacks and SDK disconnect.
Do not store recordings. Redact tokens, lobby secrets and personal audio/logs.
Private real-audio acceptance is a distinct step, not satisfied by a fake backend.

### 3. Authoritative game context

Use a small versioned bridge binding the authenticated player to the actual
character, region and z-level. The server decides eligibility; client coordinates
and user-supplied Discord IDs are not authority. Fence generations on body
change, death/observer transition, disconnect, save/reload and region transfer.
Expire stale context rather than leaving an old call active.

Define the hearing policy before implementation: distance, walls, floors,
observers and radio rules. Keep updates bounded and coalesced, outside per-tick
world scans. Preserve the player's explicit mute/block choices.

### 4. Proximity and scale

Per-participant volume and raw audio callbacks can implement spatial presentation.
They do not prove confidentiality: a modified recipient may retain audio that
the ordinary UI mutes. Before claiming private proximity, prove transport-side
membership/delivery isolation with an adversarial receiver test. If unavailable,
label the prototype honestly and do not ship it as secure proximity.

Do not join/leave a lobby for every tile crossing. Design membership hysteresis,
bounded rooms and retry budgets against actual rate limits. Verify crowded
rooms and overlapping hearing groups before adding radios or acoustic effects.

### 5. Release eligibility and acceptance

Resolve SDK use/distribution and repository-license compatibility, package
provenance and DLL loading before shipping linked artifacts. Production
communications approval is a separate dependency from a development prototype.
Account linking, presence/joins, invites and full friends UI form part of the
production feature requirements; current identify sign-in and RPC alone are not
that acceptance evidence.

Test with cloud or GitHub runners only under the current testing boundary.
Real audio, Windows UI, device behavior and connected-gameplay results must stay
explicitly unverified until tested through an authorized environment. Do not
change account settings, obtain scopes, upload vendor binaries, merge, deploy
or restart servers as a side effect of a source PR.

## Weekend sequencing

First deliver the plan and a tested companion-host slice. Then attempt the small
PTT proof if package/runtime and authorized audio-test inputs exist. Parallel
work can specify game-context contracts and cloud regression scenarios, but must
not duplicate another owner's implementation. Do not spend the weekend adding
cosmetic voice controls that imply unavailable functionality.

## Evidence checklist

- Exact commit, compiler/SDK input, commands, exits and focused test results.
- Separate fake/unit, actual OS, vendor runtime, audio and game-client evidence.
- Startup/cleanup, denial/timeout and reconnect checks, not just the happy path.
- Tick-loop impact and bounded queue/worker behavior; no unmeasured FPS claim.
- Ordinary play with voice unavailable.
- CI passed/failed/skipped/pending reported separately.
- No credentials, raw voice recordings or private player logs in artifacts.

## Official references checked 2026-11-13

- [Voice guide](https://docs.discord.com/developers/discord-social-sdk/development-guides/managing-voice-chat):
  communication scopes and lobby membership; recommended calls of at most
  25 participants; per-participant volume and audio callbacks.
- [Communications eligibility](https://docs.discord.com/developers/discord-social-sdk/core-concepts/communication-features):
  development lobby create/join and update each have a 100-per-two-hour
  per-application budget; production increases require Comms Access review and
  supporting integrated features.
- [Platform compatibility](https://docs.discord.com/developers/discord-social-sdk/core-concepts/platform-compatibility):
  check the selected standalone C++ package and target OS before linking.
- [SDK terms](https://support-dev.discord.com/hc/en-us/articles/30225844245271-Discord-Social-SDK-Terms):
  separate use/distribution obligations. This document records a release gate,
  not legal advice, acceptance of terms or a finding of license compatibility.

## DiscordPHP backend integration evidence

Reviewed [DiscordPHP source](https://github.com/discord-php/DiscordPHP/blob/991eab3e9f5a5349eda814c9f9424ed8f5c5ebc6/scripts/social-sdk-compatibility.md):
LobbyRepository supplies lobby creation, modification and membership operations;
SessionLobbyRepository supplies player-session lobby join/leave, messages and
channel linking. Reuse these APIs rather than introduce a competing Discord
client. Preserve its supported PHP compatibility in any extension.

[The lobby guide](https://github.com/discord-php/DiscordPHP/blob/991eab3e9f5a5349eda814c9f9424ed8f5c5ebc6/guide/parts/lobby.rst)
records important limits: session message sending uses player OAuth; channel
linking requires CanLinkLobby; metadata is not retained on a linked guild-channel
copy. Moderation metadata is interpreted by clients and must not be mistaken for
server-side prevention of delivery. Bot mutations do not automatically refresh
separate player-repository caches. Account for stale caches during reconciliation
and do not equate a cached member list with current admission authority.
