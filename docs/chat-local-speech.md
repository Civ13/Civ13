# Local text-to-speech in chat

In the chat panel, open **Tabs...** and enable **Read incoming IC speech aloud
on this device**. The preference is off by default and saved in this chat
browser, not on the game server. **Preview local voice** tests the installed
voice without turning on chat reading; its click also allows speech on browsers
that require a user gesture. Only new, understandable IC speech on the selected
tab is read. Old chat, whispers, nonverbal or partly understood speech, and
messages from radios, phones, OOC, or admins are not voiced.

Speech synthesis runs using a browser voice that explicitly reports itself as
local ([Web Speech API](https://wicg.github.io/speech-api/#dom-speechsynthesisvoice-localservice)).
The setting reports when the browser or an installed local voice is not available;
in that case you still receive normal chat, without voice. The game
does not generate or send speech audio, and there is no hosted fallback or audio
download. Turning the setting off drops the queue immediately.

The former server TTS switch and sound generator are retired and old
`TTS_ON` configuration entries have no effect. The old per-account toggle was
off by default and has been replaced by this per-device opt-in. Existing settings are not sent to the browser; opt in again
there if you previously enabled TTS. Existing ordinary game audio is
unaffected.

## Verification

`tests/chat/chat-local-speech.browser.test.js` exercises the real chat page,
incoming message handler, strict local-voice selection, no-voice and unsupported
cases, queue bounds, preference and history with a counted fake speech
provider. This validates no attempted network fallback. Audible playback in
Dream Seeker, whether its installed WebView exposes local voices, and available
voice languages depend on the local installation and need a real-client check.
