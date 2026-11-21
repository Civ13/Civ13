# Chat translation tests

- `test_markers.py`: offline contracts for the speech/OOC markers, the chat
  window's translation code and the server translator's wiring, limits and
  language list. CI suite `chat_translation`.
- `test_edge_service.py`: runs `tools/edge-translator/test/test.js` (the
  service's language detector and HTTP handling with a stand-in for Edge) and
  checks its pinned dependency.
- `probe.dm`: native probe of `code/modules/chat/chat_translate.dm` with a
  stand-in translator service and chat windows (off unless configured, English skip, one
  service call per text and language, cache, failures and pause, per-window and
  queue limits, request body and reply parsing). Run it with the pinned BYOND
  from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/chat_translation/probe.dm 300
```

The browser side is `tests/chat/chat-translate.browser.test.js`.
