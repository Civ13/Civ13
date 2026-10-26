# Civ13 Discord Social SDK - design checkpoint
Status, 2026-10-24: the bounded offline contract slice is implemented and tested. Production startup remains unwired and default disabled. Native Discord SDK, authentication, GUI and live presence/join integration are unimplemented. Native BYOND is the intended game scope; OpenDream is abandoned for this task.

## Pinned evidence
Civ13/Civ13: fa363b8a01ed7d936c10a6303ce1be4c26d82ab0.
Source: https://github.com/Civ13/Civ13/tree/fa363b8a01ed7d936c10a6303ce1be4c26d82ab0/tools/opendream-client/native

Launcher: .NET 8 Windows-x64 console, source 1.0.7; README released 1.0.6. No release-readiness claim. Program.Main dispatches DreamSeeker then returns to its menu; the local-receipt path exits. No login/travel acknowledgement exists; Process.Start proves dispatch only.

Native seam: ServerBrowser.Run -> IServerDiscovery.Recheck -> ServerCatalog.NativeStart. Connection.Start is dormant OpenDream. Targets: civ13.com/valzargaming.com on 1714/1715, without mode/online assumptions. Preserve full-answer public IPv4 checks, selected identity, original 60-second status proof, DNS freshness, shared pacing and explicit J/Back. Display cache cannot authorize launch.

Root AGENTS.md/workflow read; no versioned .agents or nested guide in scope. Reuse CachedJoinTests/ServerDiscoveryTests/TopicPacingTests fixtures. Keep social tests separate from the updater executable-replacement runner.

DiscordPHP read-only pin: 212bed1e0481dab3721795e0926bf133d34a674e.
Source: https://github.com/discord-php/DiscordPHP/tree/212bed1e0481dab3721795e0926bf133d34a674e
Selected API paths match that pin; root guidance/relevant skills read.
- src/Discord/OAuth2/SessionManager.php: exchangeAuthorizationCode, revoke, refresh, bot/external provisional issuance, unmerge and child tokens already exist.
- OAuth2/Session.php: separate player Bearer HTTP client and SessionLobbyRepository.
- Repository/LobbyRepository.php: bot/backend lobby administration and roster operations.
- Repository/SessionLobbyRepository.php: player lobby/message operations.
- Both lobby createInvite methods return linked-channel invite codes; they do not implement Client::SendActivityInvite or native join callbacks.
- ApplicationIdentityRepository and signed webhook support already cover their backend surfaces.
Existing coordinator inventory: https://github.com/discord-php/DiscordPHP/blob/212bed1e0481dab3721795e0926bf133d34a674e/scripts/social-sdk-compatibility.md
No library patch needed here. Inventory tests are historical. Parent routes later gaps to the existing coordinator.

## Verified official docs, not runtime evidence
[P] Platform: https://docs.discord.com/developers/discord-social-sdk/core-concepts/platform-compatibility
Windows x64 10+ is generally available. Standalone C++20+, Unity and Unreal are listed; standalone .NET is not. Unity C# examples do not establish support for this console launcher. Linux is experimental.

[R] Releases: https://docs.discord.com/developers/discord-social-sdk/core-concepts/release-cadence-and-support
Lists current 1.10, supported 1.6-1.10. Downloadable patch/headers/hash unverified.

[RP] Presence: https://docs.discord.com/developers/discord-social-sdk/development-guides/setting-rich-presence
Desktop RPC presence uses SetApplicationId and UpdateRichPresence without Connect/OAuth, with a valid application ID and running Discord desktop client. No provisional account is needed for that presence-only path.

[S] Scopes: https://docs.discord.com/developers/discord-social-sdk/core-concepts/oauth2-scopes
Authenticated presence/friends: openid sdk.social_layer_presence. Communications: openid sdk.social_layer. The proposed RPC presence experiment requests no scopes. Later auth must decide confidential/public client architecture; never ship a client secret.

[I] Invites: https://docs.discord.com/developers/discord-social-sdk/development-guides/managing-game-invites
Party/join/platform fields enable joins. SetActivityJoinCallback handles joining; RegisterLaunchCommand registers locally. Presence scopes support joins; message text needs communication scopes. Cold start: 180-second pending window, callback before Connect. Unauthenticated RPC cold joins remain unproven for this launcher; keep disabled.

[A] Access/setup: https://docs.discord.com/developers/discord-social-sdk/getting-started/using-c%2B%2B
Documents developer team/application, Social SDK enablement and Downloads. Windows runtime needs discord_partner_sdk.dll next to the executable; callbacks require RunCallbacks. No portal changes or downloads occurred.

[C] Communication access: https://docs.discord.com/developers/discord-social-sdk/core-concepts/communication-features
Text/voice is capped before expanded access; full access has feature, UI, moderation and submission requirements. Chat/voice needs separate product scope and in-game UX.

## Architecture proposal
.NET owns projection/intent behind an async adapter. Pump native callbacks independently of blocking Console.ReadLine.
- In-process C++ shim: custom C ABI, exception/lifetime containment and DLL packaging; no verified official .NET binding.
- Optional C++ helper: preferred later prototype for supported standalone SDK/crash isolation, subject to licensing. Requires bounded versioned local IPC/packaging; no secrets in arguments. Process separation does not settle licensing.
- DiscordPHP/ReactPHP: reuse backend contracts later; bot presence cannot replace player presence. No invented native-method HTTP routes.

Presence: "Browsing Civ13 servers" or brief "Opening BYOND"; no playing/shard/party claim without authority. Exclude ckeys/CIDs/coordinates/body/save/custody data. Clear on disable/exit, ignore late callbacks, and preserve ordinary launching on failure.

## Implemented offline first slice
Only pure contracts, a no-op adapter and focused fake-driven tests are implemented. These are application contracts, not Discord SDK APIs. PresenceFrame exposes immutable generation/revision, launcher phase, bounded text, optional lifetime and monotonic freshness. JoinIntent is constructed only by its strict Parse method.

~~~csharp
enum LauncherPhase { Browsing, Dispatching }
record JoinIntentEnvelope(long Generation, Guid IntentId, JoinIntent Value);
interface ISocialClient {
    void AdvanceGeneration(long generation);
    Task UpdateAsync(PresenceFrame frame, CancellationToken ct);
    Task ClearAsync(long generation, CancellationToken ct);
    event Action<JoinIntentEnvelope>? JoinRequested;
}
~~~

Files: Social/{PresenceProjection,ISocialClient,JoinIntent,JoinIntentController}.cs and SocialContracts tests. No-op/fake only; production startup unwired. No CLI/deep link, native adapter, registry registration, SDK/auth/download.

PresenceProjection is pure; default disabled means no adapter activity. Details/state are fixed launcher text below 96 UTF-8 bytes. Dispatching has a 15-second monotonic lifetime; a future native adapter must enforce live expiry/clear scheduling. Generation fences disable/replacement and revisions reject older updates within one generation. SocialSession exercises enable/update/disable with explicit calls; no process-exit hook or production timer is installed. The fake rejects expired and stale completions; cancellation alone is insufficient.

JoinIntent wire proposal: strict UTF-8 JSON object with v=1, target, and optional map/mode/round. Target is exactly one of official-1714, official-1715, vzg-1714, vzg-1715, mapped to existing GameTarget entries. Whole payload <=512 bytes; each optional string 1-96 bytes. Reject duplicate/unknown fields, wrong types/versions, invalid UTF-8, control characters, raw endpoints, URLs, paths and command arguments. Envelope metadata is local. No tokens/lobby secrets/transfer credentials. This public hint never authorizes admission.

Controller APIs: Receive(envelope), Cancel(), AcceptAsync(ct). Receive validates one pending intent and cancels superseded work, with zero I/O. Cancel invalidates pending/in-flight generations. Explicit acceptance alone invokes injected discovery, compares fresh identity, Rechecks and prepares NativeStart. Recheck active intent/generation immediately before the fake launch delegate. Missing/changed identity, expired status/DNS, deferral/cancellation or dispatch failure cannot succeed. Cooldown needs explicit J; Back cancels without background retry. No real process delegate in this slice.

Offline tests: disabled/no adapter work; truthful projection/expiry; update/clear; late completion after disable; malformed/oversized/duplicate/unknown target; no I/O on receipt; explicit accept only; supersession/Back during recheck; changed/missing map/mode/round; cooldown without retry; expiry and DNS refusal; dispatch exception; manual launch unaffected by adapter failure. Inject clocks, discovery, output and launch. Reuse existing fixtures where practical. Do not run the updater replacement runner, public DNS/Topic, Discord, SDK or BYOND.

No DM/GUI/backend/release/feed changes. Further native integration and production wiring require separate review; merge remains a separate decision.

## Licensing/access gates and travel
[L] SDK terms: https://support-dev.discord.com/hc/en-us/articles/30225844245271-Discord-Social-SDK-Terms
[D] Developer terms: https://support-dev.discord.com/hc/en-us/articles/8562894815383-Discord-Developer-Terms-of-Service
[G] Repo AGPLv3: https://github.com/Civ13/Civ13/blob/fa363b8a01ed7d936c10a6303ce1be4c26d82ab0/LICENSE

[L] permits SDK distribution integrated into an application subject to its terms and imposes restrictions/age requirements. Review compatibility with [G], including launcher authorship/license scope, before linking/distribution. Neither bridge option is declared legally permitted. No agreement was accepted. The owner must separately select an application and authorize access/setup [A]. Pin any later SDK version/hash/notices and reconcile DLL/helper packaging with current single-file release verification.

Later native acceptance: authorized isolated opt-in RPC presence, Discord absent/present, callback pumping, disable/exit cleanup. Invites additionally need reviewed launch registration and warm/cold join evidence. OAuth needs explicit grant/storage/revocation design. Chat/voice requires separate scope, UX, moderation, age, microphone and access decisions. None is authorized here.

Manual/direct BYOND joining remains supported without launcher or Discord. Servers retain identity, authentication, body custody, transfer reservation, source release and destination commit authority. An invite or Discord identity cannot reclaim a body or authorize travel. Never place travel receipts in presence, join data or arguments. Manual admission/recovery must remain possible.

## Evidence/portable handoff
Implemented contracts passed 266 deterministic offline assertions using installed .NET SDK 8.0.319, with zero build warnings/errors. The existing Launcher.Tests project compiled only; its updater replacement runner was not executed. Production Program and existing discovery/status/DNS/pacing/BYOND validation code are unchanged. Final status-document changes use static/whitespace checks without another managed execution.

The private portable packet retains source/tests, patch, logs, digests and the original design checkpoint. The sparse checkout borrows objects and is not itself portable. Native SDK conformance, authenticated flows and live game acceptance are unverified.

No local secret/config reads, Discord messages, application registrations, authentication grants, SDK downloads, native game launches/restarts or deployments are part of this slice. SDK licensing/access and application selection remain future gates.
