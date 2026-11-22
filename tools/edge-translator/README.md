# Edge chat translator

A small local service that lets Civ13 worlds translate chat with Microsoft
Edge's built-in on-device Translator (Edge 148+). The game sends a chat line
and the reader's language; the service detects the line's language, has Edge
translate it, and answers. It listens on `127.0.0.1` only and keeps nothing
but Edge's language packs in its own profile folder. See
[docs/chat-translation.md](../../docs/chat-translation.md).

## Run it (Windows host)

The host service runs it: add `"chat_translator": {}` to the group config (see
[scripts/shard-group/README.md](../../scripts/shard-group/README.md#chat-translator)).
It installs the pinned `playwright-core`, starts the service, restarts it if it
exits, and gives every region `CHAT_TRANSLATE_URL`. The launcher's **Translator**
tab shows it and starts or stops it. Needs Node.js and Microsoft Edge.

By hand (testing): `start.bat`, or `node edge_translator.js --port 55581`.
Options: `--profile <dir>` (default `edge-profile` here), `--edge <msedge.exe>`,
`--headed` (a visible Edge window, if hidden mode cannot download packs).

Check it with `curl -s http://127.0.0.1:55581/health`, or translate a line:
`curl -s -X POST http://127.0.0.1:55581/translate -H "Content-Type: application/json" -d "{\"text\":\"hola amigo\",\"target\":\"en\"}"`.

## Behaviour

- Language packs: Edge downloads each language pair the first time it is
  needed (the first pair took a few minutes and about 400 MB on the host;
  later pairs take seconds). Until a pair is ready its lines are answered
  with no translation. Playwright's `--disable-component-update` default is
  removed, because Edge fetches packs through its component updater.
- Detection: Edge's LanguageDetector reported "Model not available" on the
  host, so `detect.js` detects by script (Cyrillic, CJK, Arabic, Greek and so
  on) and, for Latin-script languages, by common words and letters.
- One line at a time through Edge, up to 40 waiting (then 503), 500
  characters per line, 15 s per line. The first line of each pair after a
  start waits up to 9 s for Edge to load the pack. Each Edge call has a 5 s
  deadline: Edge unloads idle translators and the old object then hangs, so
  a translator that throws or hangs is dropped and made again for the same
  line. Pairs used in the last 30 minutes are kept warm every 45 s; idle ones
  are released.
- `start.bat` starts the service again 10 s after it or Edge stops.
- Tested on the host (Edge 158, hidden): es>en 0.9 s first and 30-100 ms
  warm, fr>en and en>de about 0.5 s, ru>en and ja>en translated about a minute
  after their first line (pack download).

Tests (no Edge needed): `node test/test.js`.
