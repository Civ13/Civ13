# Push-to-talk prototype (issue #5122, Phase 2)

`civ13-voice-proto.exe` is a standalone Windows console tool that puts two
players in one Discord Social SDK voice call with push-to-talk. It is separate
from the launcher, the companion child and the game, so it cannot affect
joining a server. It exists to prove the real SDK voice path on two PCs before
any of it moves into the companion.

## What it does

1. Asks Discord for the communication scopes
   (`Client::GetDefaultCommunicationScopes`) with a fresh PKCE verifier. The
   launcher's identify-only login is not reused. Closing or refusing the
   prompt exits with code 3.
2. Exchanges the code with `Client::GetToken` (public client), connects, and
   joins the lobby named by the shared secret with `CreateOrJoinLobby`, then
   `StartCall`.
3. Sets the call to push-to-talk mode with a 20ms release delay. The
   microphone opens only while SPACE is held **in this console window**. A key
   press that the console did not deliver never counts, and focus loss or a
   missed key-up (no repeat event for 1.2 seconds) closes it again
   (`voice_control.hpp`, `PushToTalk`). It never reads global keyboard state,
   which antivirus flags as keylogging.
4. M mutes, D deafens, I lists microphones and switches to the next one,
   P lists participants, 1-9 mutes a participant for you only
   (`Call::SetLocalMute`), Q ends the call, leaves the lobby and quits.
   Ctrl+C or closing the window does the same.
5. Refreshes the access token when the SDK reports expiry, or five minutes
   before the reported lifetime ends. A failed refresh keeps the call.
6. Prints Discord and call status changes, joins/leaves, talking indicators and
   device changes. Tokens and the lobby secret are never printed. Nothing is
   recorded or written to disk.

Exit codes: 0 closed, 2 bad arguments, 3 consent refused, 4 token failure,
5 lobby or call failure, 6 connection lost.

## Discord application settings (one time, application owner)

The prototype exchanges the code on the player's PC, so it needs the
application's OAuth2 page to have:

- **Public Client** turned on.
- Redirect `http://127.0.0.1/callback` added.

Discord recommends against shipping with Public Client on. The released path
(Phase 5) moves the code exchange to the server side through DiscordPHP, and
Public Client goes back off then. Development voice is rate limited (about 100
lobby joins per two hours); production Comms Access is a separate application.

## Build (Windows, MSVC, external SDK)

```powershell
.\Build-VoiceProto.ps1 -SdkRoot D:\GitHub\discord-social-sdk-1.10.19337
```

Output: `build\voice\civ13-voice-proto.exe` with the SDK runtime DLLs beside
it, and `build\civ13-voice-proto.zip` with the same files for the second
tester. The SDK is never committed; `build/` is ignored.

## Two-PC test

Both testers pick the same secret, for example `civ13-voice-test-01`, then:

```powershell
cd build\voice
.\civ13-voice-proto.exe 1562126764849897544 civ13-voice-test-01
```

Check, and note any that fail:

1. Refusing the Discord prompt exits with code 3; running again and approving
   reaches "In the call".
2. Each tester sees the other join.
3. Nobody is heard until SPACE is held; "[mic ON]" appears only while held.
4. Holding SPACE then clicking another window stops transmission.
5. M and D work and show on the other side.
6. 1 or 2 mutes the other tester for you only; they can still hear you.
7. Unplugging or switching a headset prints a device change; I switches mic.
8. Turning Wi-Fi off for a few seconds shows Reconnecting, then the call
   resumes.
9. Q leaves cleanly and exits with code 0.

The portable rules (arguments, push-to-talk tracking, transmit gate, session
flow, refresh timing) run in CI as `voice-tests` through `Build-Offline.ps1`.
