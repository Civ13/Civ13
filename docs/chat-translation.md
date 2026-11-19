# Recipient-side chat translation

## Player behavior

English remains required for in-game player communications. Translation is an accessibility aid for the recipient, not permission to send in another language, not a moderation decision, and not a change to what other players see. A recipient can choose **Translate** on an eligible line to get an English rendering, or choose a personal reading language (including for incoming English). Keep the original visible. Never replace stored, relayed or moderation text. No automatic publishing, language-policy enforcement, or history export.

Ship the first working slice for player OOC and normal nearby typed IC speech. Direct LOOC and fully heard whispers can use the same contract once verified; use the separate admission paths for repeaters, radio, phones, voicepipes, and cross-region channels instead of assuming that every line in the IC tab is valid. Exclude system text, NPC/emote output, admin/private messages, hidden or garbled content, and spectator-only channels from the pilot.

## Server contract: mark only recipient-visible eligible text

1. In [client_verbs.dm](../code/modules/client/client_verbs.dm), wrap the message body of the final recipient's OOC line, after the existing moderation, mute and delivery checks. Preserve names, links, ranks, and channel labels outside that body. Add explicit equivalent marking at player relay sinks when their origin and eligibility are independently verified.
2. In [hear_say.dm](../code/game/mob/hear_say.dm), mark the final readable speech body immediately before display formatting for that recipient, not the shared input. Track eligibility explicitly from the sender and recipient: no marker on speech altered by game language proficiency (including partial comprehension), stars/scramble, distance masking, nonverbal visibility loss, or hearing/sleep restrictions. An IC tag or language label alone proves nothing. In [whisper.dm](../code/game/mob/living/carbon/human/whisper.dm), the eavesdrop branch applies stars before `hear_say`; carry an explicit opt-out on that path rather than guessing from the rendered string. Verify the equivalent rule on sender-side obscuration as well.
3. A single server-created body marker (for example `span.chat-translation-source`) wraps only the displayed body. No alternate or original hidden text goes in attributes, JSON, tooltips, client caches, or translation requests. Do not source from `original_message` or `alt_message`/overlay/TTS. Audit that untrusted message text cannot forge a marker; test the live sanitization paths. The listener must not be sent the hidden plaintext to make translation work. Translation must not affect appearance, language skill, hearing, or server logs.

## Client contract: on demand and on device

- In [chat.html](../interface/chat/chat.html), after normal sanitization, offer a per-line button only for an eligible single body. Give the translator only that body's plain `textContent`. Keep translations labelled and adjacent or in a local detail panel. Use `textContent` for results, never HTML. Do not send the display name, channel, or character identity to the translator.
- Start with the browser's [on-device Translator API](https://learn.microsoft.com/en-us/microsoft-edge/web-platform/translator-api). Feature-test it and the selected pair. Prefer language detection where exposed, with manual source override; require a click before downloading a model or creating a translator where user activation is needed. Unsupported pairs and missing/offline engines leave the original usable. No paid API, remote fallback, or logging of untranslated or translated chat.
- Browser support is not Dream Seeker support. Verify both presence and a real translation in the actual embedded runtime, with the correct origin/security restrictions. If unavailable, keep this path fail-closed and prototype a separately reviewed, local-only provider before claiming native coverage. See [WebView2 feature differences](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/browser-features).
- No action on message arrival. Bound input/output and concurrent work; discard late results after clear, trim, reconnect or dialog close; dispose of models/translators as appropriate. Keep the original HTML as the basis for repeats, moderation, and history. Do not persist translations or replay translation jobs on reconnect.

## Acceptance before enabling

- [ ] With a fake local provider, prove Spanish typed into eligible IC/OOC can be rendered in English on request, and eligible English can be read in another selected language. The original remains unchanged.
- [ ] Same IC line sent to two recipients: fully comprehended text is eligible, partial or scrambled speech has no affordance and no hidden source reaches the translator. Add negative cases for sender-side obscuration, eavesdropping, deaf/asleep listeners, nonverbal visibility loss, and forged message markup.
- [ ] OOC mute/permission behavior does not change. Any added relay, whisper or device path has its own positive and negative checks.
- [ ] Browser fixture: no automatic requests; supported, unsupported, download and error states; result rendered as plain text; no chat-history persistence or changes to repeat behavior; late work cannot reappear after clearing a line.
- [ ] Pinned Dream Maker compile and repository preflight before pushing gameplay changes, followed by exact-head CI and a real Dream Seeker check on an authorized isolated cloud or hosted test runner. Do not claim the machine-translation provider works in BYOND until the real check passes.

This document is a proposed implementation contract; it does not add chat UI or translation behavior.
