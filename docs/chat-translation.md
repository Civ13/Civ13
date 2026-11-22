# Recipient-side chat translation

## As built (Val, 2026-11-21)

Val approved the feature and changed two choices from the proposal below: all
chat is translated automatically, and the reader's language defaults to
English. Val, 2026-11-22: until a player saves a choice under **Tabs... >
Translation** (key `civ13-chat-translate-v2`, that computer only), the first
offered language in `navigator.languages` (the Windows display language in
WebView2) decides: English means off, any other offered language means on into
that language. The old v1 setting keeps only its language (non-English means on).
With automatic translation off, a marked line that does not look English (or
any marked line, for a non-English reader) gets a **Translate** button; only a
pressed line is sent, ahead of automatic lines, and automatic translation stays
off. Val, 2026-11-22: an English reader saw no way to translate a German OOC line. Only words players typed are translated: unmarked game
messages are never sent ("Thibault Sommer makes a trench." had come back as
"trench coat"), lines with fewer than 3 letters are skipped, and the service's
detector needs a clear winner with at least two hints in lines of three or
more words.

- Server: `hear_say` wraps speech the listener fully understood in
  `<span class='chat-tr'>` and garbled speech (scrambled, starred, nonverbal
  unseen, animal noises) in `<span class='chat-notr'>`. Radio, phone and
  voicepipe speech is marked by each device proc with `chat_translate_mark`
  after the frozen comprehension helper (`tests/device_hearing`): `chat-tr`
  when the words came through unchanged. Emotes mark only words a player typed
  (Me verb, `^` prefix, the emote box). OOC, LOOC and cross-region OOC
  bodies are `chat-tr`.
- Client (`interface/chat/chat.html`): each new live line is checked by the
  browser's `LanguageDetector`; if it is in another language with confidence
  of at least 0.6, the browser's `Translator` puts a labelled translation under
  the untouched original. Lines with `chat-notr` are skipped; lines with
  `chat-tr` send only that body; other lines (canned emotes, game messages)
  are never sent. Restored history is never translated, and translations are stripped
  before history is saved.
- A missing language pack shows a **Download** button once per language pair
  per session; nothing downloads without a click. Up to 20 lines wait in the
  queue (oldest dropped), 500 characters each, one at a time, 8 s timeout.
- With no `Translator` or `LanguageDetector` in the client, the setting says so
  and chat is shown as written.
- Tests: `tests/chat/chat-translate.browser.test.js` (fake on-device APIs in
  headless Chromium) and `tests/chat_translation/test_markers.py`.

### Server translation (Val, 2026-11-21)

Dream Seeker's WebView2 (157) has `Translator` and `LanguageDetector`, but
every language pair reports "unavailable" and there is no switch a server can
flip for its players, so Val asked for a workaround. Val then ruled out Ollama
as the translator and asked for Edge: the world translates through a local
service that drives Microsoft Edge's own on-device Translator
(`tools/edge-translator`, see its README), and `code/modules/chat/chat_translate.dm`
talks to it.

- Off unless `CHAT_TRANSLATE_URL` (the service, e.g. `http://127.0.0.1:55581`)
  is set. On a region group the host service runs the service and sets it for
  every region when the group config has `"chat_translator"`; the launcher's
  Translator tab shows and controls it (Val, 2026-11-21).
- When the chat page is ready the world calls `setTranslateServer("1")`. The
  page then sends each new eligible line (the same text the on-device path
  would use) as `byond://?chat_translate=<id>&lang=<reader's language>&text=`.
  The text goes only back to the world that sent the line.
- The world answers every request with `receiveTranslation(id, source, text)`,
  `text` empty when no translation is needed or possible, so the page's
  one-at-a-time queue never stalls (20 s timeout per line).
- English lines for English readers (plain ASCII where at least a quarter of
  the words are common English words) never leave the world. Otherwise one
  `POST /translate {"text","target"}` call serves every reader of the same
  text and language. Translations and confirmed same-language replies are
  cached in memory (1000 entries). Other empty replies leave that line
  unchanged without preventing translation of an identical later line.
  Limits: 500 characters, 40 distinct texts waiting (oldest dropped), 40
  requests per window per minute, 20 s per call, five minutes off after three
  failed calls in a row. Nothing is logged or written to disk.
- Edge on the host (158, probe 2026-11-21): translation works once its
  component updater may fetch language packs (es>en, fr>en, en>de translated;
  20-80 ms warm). Its LanguageDetector never loaded, so the service detects
  languages itself (`detect.js`).
- Tests: `tests/chat_translation/probe.dm` (native, stand-in service and
  windows: `python3 tests/ecology_spawning/run_linux.py . tests/chat_translation/probe.dm 300`),
  `tools/edge-translator/test/test.js` (run by `test_edge_service.py`), the
  server-mode case in the browser test, and `test_markers.py`.

The rest of this file is the original proposal, kept for its acceptance list.

## Player behavior

English remains required for in-game player communications. Translation changes only what a recipient can read locally; it does not grant permission to send in another language, enforce the rule, or change what anyone else sees. Keep the original visible and authoritative for delivery, repeats, history and moderation. Never post translations back to chat.

Ship the first working slice for player OOC and normal nearby typed IC speech. Direct LOOC and fully heard whispers can use the same contract once verified; use the separate admission paths for repeaters, radio, phones, voicepipes, and cross-region channels instead of assuming that every line in the IC tab is valid. Exclude system text, NPC/emote output, admin/private messages, hidden or garbled content, and spectator-only channels from the pilot.

## Server contract: mark only recipient-visible eligible text

1. In [client_verbs.dm](../code/modules/client/client_verbs.dm), wrap the message body of the final recipient's OOC line, after the existing moderation, mute and delivery checks. Preserve names, links, ranks, and channel labels outside that body. Add explicit equivalent marking at player relay sinks when their origin and eligibility are independently verified.
2. In [hear_say.dm](../code/game/mob/hear_say.dm), mark the final readable speech body immediately before display formatting for that recipient, not the shared input. Track eligibility explicitly from the sender and recipient: no marker on speech altered by game language proficiency (including partial comprehension), stars/scramble, distance masking, nonverbal visibility loss, or hearing/sleep restrictions. An IC tag or language label alone proves nothing. In [whisper.dm](../code/game/mob/living/carbon/human/whisper.dm), the eavesdrop branch applies stars before `hear_say`; carry an explicit opt-out on that path rather than guessing from the rendered string. Verify the equivalent rule on sender-side obscuration as well.
3. A single server-created body marker (for example `span.chat-translation-source`) wraps only the displayed body. No alternate or original hidden text goes in attributes, JSON, tooltips, client caches, or translation requests. Do not source from `original_message` or `alt_message`/overlay/TTS. Audit that untrusted message text cannot forge a marker; test the live sanitization paths. The listener must not be sent the hidden plaintext to make translation work. Translation must not affect appearance, language skill, hearing, or server logs.

## Client contract: on-device, recipient-controlled translation

- Keep **Automatically translate new chat** off by default. In local client preferences, a player chooses a reading language (including English to help read unexpected non-English text) and explicitly enables the option. Show the local provider and pair setup status before activation. Offer a per-line **Translate** button for eligible text even with automatic mode off. Keep the preference on this client only; switching it on is not authorization to download arbitrary language models or upload chat.
- Start with the browser's [on-device Translator API](https://learn.microsoft.com/en-us/microsoft-edge/web-platform/translator-api). Feature-test the provider and each pair. Treat a pair as ready only after it is locally available and a live translator is successfully initialized. For pairs requiring a model download or user activation, show a separate, explicit setup action naming the pair; require a user gesture before setup/download. A new message must never trigger a download or activation prompt. Local language detection can select an already-ready pair; if detection is unavailable or ambiguous (for example a one-word line), use an explicit configured source or leave the original and allow manual source selection. Never guess a pair requiring setup, translate same-language text, or use a cloud fallback.
- In [chat.html](../interface/chat/chat.html), only the normal live-insert path can queue automatic work, after sanitization and the server's recipient-specific eligibility marker have been verified. Pass only the marked plain `textContent` of one body, not display names, channel metadata or alternate text. Render a visibly labeled translation alongside the unchanged original using `textContent`, never HTML. The manual button uses the same eligibility and local-provider gates; if a pair is not ready, it can initiate setup with the player's explicit approval and translate the requested line when ready.
- Bound work per client: cap eligible input and output length, pending queue depth and concurrent work; deduplicate by line instance, locale pair and live preference generation. Keep the game responsive under bursts: drop automatic work on overflow or timeout and leave the manual button available. Turning automatic mode off, changing languages, clearing or trimming the line, or reconnecting invalidates in-flight or queued automatic work and prevents late results from appearing. Do not pass historical/replayed/repeated lines to automatic mode or backfill when enabling or changing a preference. Do not persist translation output or queue contents; dispose of local resources when unused.
- Desktop browser support or its built-in page translation is not Dream Seeker support. In an isolated authorized runtime, prove both availability and a real local translation in the embedded chat origin. If unavailable, unsupported, offline with an unready pair, or otherwise unable to honor the local-only contract, leave originals readable, with a clear unavailable state; never switch to a network translator. A different local-only provider needs a separately reviewed design and the same runtime proof. See [WebView2 feature differences](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/browser-features). No provider may send chat, its metadata or translations outside the client, or record them.

## Acceptance before enabling

- [ ] With a fake local provider, prove eligible English OOC and fully comprehended English IC automatically render in a selected reading language only after explicit opt-in and local pair readiness. Use a synthetic non-English incoming fixture to verify English is also a valid reading language, without changing the game's English send rule. Manual translation works on eligible lines when automatic mode is off. Original, relay, and moderation text are unchanged.
- [ ] Same IC line sent to two recipients: fully comprehended text is eligible, partial or scrambled speech has no affordance and no hidden source reaches the translator. Add negative cases for sender-side obscuration, eavesdropping, deaf/asleep listeners, nonverbal visibility loss, and forged message markup.
- [ ] OOC mute/permission behavior does not change. Any added relay, whisper or device path has its own positive and negative checks.
- [ ] Browser fixture: default off, preference changes, pair ready/unready, failed or unsupported setup, same-language and ambiguous input, approved download (never on arrival), plain-text output, and no egress. Flood the queue and prove bounds, deduplication, manual fallback, no history replay or backfill, and no stale result after disable, locale switch, clear, trim or reconnect.
- [ ] Pinned Dream Maker compile and repository preflight before pushing gameplay changes, followed by exact-head CI and a real Dream Seeker check on an authorized isolated cloud or hosted test runner. Do not claim the machine-translation provider works in BYOND until the real check passes.

This document is a proposed implementation contract; it does not add chat UI, automatic translation, or a Dream Seeker provider.
