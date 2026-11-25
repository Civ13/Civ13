# Optional launcher voice: implementation and acceptance

Tracking issue: [#5122](https://github.com/Civ13/Civ13/issues/5122).
Implementation status and next acceptance step reviewed 2026-11-25.

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
| WindowsCompanionFactory | Parent process/pipe source and Windows child-process checks | Released vendor binding through the launcher |
| Game proximity voice | Phase 3 game roster and launcher volume rules, with synthetic tests | Connected TDM acceptance and server-side audience isolation |

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

Status (2026-11-15): source implemented and offline tested. The child endpoint
(`companion/main.cpp`, `endpoint.cpp`, `windows_pipe_io.cpp`) parses the fixed
argument layout, adopts the inherited overlapped pipe ends and runs the existing
Host until Stop, EOF, lease expiry, cancellation or failure. Portable endpoint
tests use an injected clock; `child-tests.exe` launches the real executable over
real Windows pipes on the CI runner. Production builds answer Hello with an
unavailable backend, so activation stays off. Vendor runtime acceptance is not
claimed.

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

Status (2026-11-15): source implemented as a standalone prototype,
[`civ13-voice-proto.exe`](../tools/opendream-client/native/companion/voice/README.md),
outside the companion and launcher. Its portable rules are offline tested in CI
(`voice-tests`). The [Phase 2 acceptance update on #5122](https://github.com/Civ13/Civ13/issues/5122)
records push-to-talk audio on two separate Windows PCs with the standalone
development prototype and SDK 1.10.19337. This did not exercise the TDM
roster, launcher-to-game binding, or production permissions.

### 3. Authoritative game context

Use a small versioned bridge binding the authenticated player to the actual
character, region and z-level. The server decides eligibility; client coordinates
and user-supplied Discord IDs are not authority. Fence generations on body
change, death/observer transition, disconnect, save/reload and region transfer.
Expire stale context rather than leaving an old call active.

Define the hearing policy before implementation: distance, walls, floors,
observers and radio rules. Keep updates bounded and coalesced, outside per-tick
world scans. Preserve the player's explicit mute/block choices.

Design (Val, 2026-11-15): one Discord voice lobby per region plus one per
team, TDM on civ13.com first. Hold the talk key and players whose characters
can see you hear you, louder when closer. Hold the team key and your whole
faction in the region hears you.

- Identity is the BYOND key. CivilizationBot gives each ckey a Discord
  provisional account through the bot token endpoint, or uses the account the
  player linked. Players need no Discord login, and Public Client stays off.
  Guest keys are excluded.
- The launcher joins with `byond://host:port?civ13_voice=<key>`, a random
  per-connection secret. The game lists `{ckey, key, team}` for every voice
  player in a roster it POSTs to the bot (`/webhook/<server>/voice_roster`,
  webhook key in a header, https or loopback only). The bot answers with
  `{"ids": {ckey: Discord user ID}}`.
- After the join, the raw key never crosses the network again. The launcher
  asks the bot for its access token with `sha256("civ13-voice-token:" + key)`,
  and the bot seals the answer with AES-256-GCM under
  `HKDF-SHA256(key, info "civ13-voice-seal")`. The bot's web API is plain
  HTTP, so an eavesdropper sees only sealed bytes. The bot sets the members of
  the region and team lobbies from the roster.
- Ten times a second the launcher asks the game
  `civ13_voice_state=sha1("civ13-voice-state:" + key)` for
  `{v, gen, me, hear: {id: volume}, speak, talk, team, team_talk, token_url}`.
  That call has its own per-key limiter ahead of the generic topic cooldown,
  so players sharing one address are not throttled.
- Talk (`talk`) and team radio (`team_talk`) are held game keybindings, set in
  OOC > Keybindings with the other action keys (defaults F5 and F6, any of
  F4-F10 or Numpad0, per typing/hotkey mode). The voice app transmits only
  while the game says the key is down, so it never reads the keyboard. A hold
  ends on release, on rebinding, or after two minutes. Region-call participants not in
  `hear` are muted, `gen` changes on a new body or death, and an answer older
  than three seconds mutes everyone. Dead, observing and lobby players hear
  nobody in the region call. Knocked-out players hear but cannot talk.
- Hearing policy: same level, line of sight (walls block, darkness does not),
  10 tiles; volume 100 within 2 tiles, then 75, 50 and 30.
- The launcher turns voice on when `voice\civ13-voice.exe` sits beside it,
  adds the key to the join link and hands it to that app on stdin
  (`tools/opendream-client/native/VoiceChat.cs`,
  `companion/voice/voice_client.cpp`). Without the app, joining is unchanged.
- Status: game side source implemented and native-probe tested
  (`tests/voice_chat/`, `tests/action_keybindings/`). Bot side in
  Civilizationbot `VoiceLobbies.php`, offline tested. Voice app rules and CNG
  crypto offline tested (`companion/tests/region_voice_tests.cpp`). Not yet
  runtime verified with real players.

### 4. Proximity and scale

Per-participant volume and raw audio callbacks can implement spatial presentation.
They do not prove confidentiality: a modified recipient may retain audio that
the ordinary UI mutes. Before claiming private proximity, prove transport-side
membership/delivery isolation with an adversarial receiver test. If unavailable,
label the prototype honestly and do not ship it as secure proximity.

Use DiscordPHP-managed membership for the first isolated test room. Discord
[documents](https://docs.discord.com/developers/resources/lobby#create-lobby)
that SDK clients cannot join or leave a lobby created by the server API on
their own. That makes a server-created private room a candidate, but does not
prove that removing a member stops their media promptly or that the same
membership model can represent overlapping visibility groups.

The next slice is a bounded TDM development acceptance test, not a production
rollout:

1. Prove that a test caller outside an authorized roster receives no audio.
   With two authorized test participants talking, revoke one membership and
   timestamp the game decision, bot receipt, confirmed Discord membership update,
   and SDK-observed end of media delivery. Measure end-to-end from the game
   decision. Local mute and token invalidation are separate checks; neither is
   evidence of removal or media cessation. Record only synthetic pass/fail
   markers, timings and SDK versions, not audio or credentials.
2. Repeat for disconnect and reconnect, character swap, observer or death
   transition, and faction change. Explicit loss of eligibility starts revocation
   without reconnect grace. If grace is allowed for transient disconnects, reserve
   it for the same authenticated session and audience; stale context must expire
   on a bounded schedule independent of roster traffic. Extend the bot's
   fake-clock coverage for delayed and absent follow-up rosters and confirm the
   deadline is not extended by a replayed or stale update. An expired or unknown
   admission decision must be fail-closed. Ordinary launcher join and BYOND text
   must remain available when voice is denied.
3. Use a fixed small room and count the actual lobby writes. Do not join/leave
   per tile or promise proximity privacy from client-set volume. The
   [documented development budgets](https://docs.discord.com/developers/discord-social-sdk/core-concepts/communication-features#development-rate-limits)
   are 100 create/join and 100 update requests per two hours, each per
   application. Simulate revocation delays, retries and rate-limit responses
   before pursuing an overlapping proximity topology.

Phase 4 remains open until transport-side isolation and safe revocation are
observed on the authorized test environment. Phase 5 remains separate.

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
