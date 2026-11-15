# Voice chat tests (game side)

- `test_voice_chat.py`: offline source contracts. These cover the DME include,
  the voice topic sitting after the ban list but before the two-minute topic
  cooldown, the join-link key being read before TopicData is dropped, no
  logging of keys, the roster going only to https or loopback, and guests
  being left out. CI suite `voice_chat`.
- `probe.dm`: native probe of join-link keys, volume by distance, who is heard
  (sight, walls, levels, knocked out, dead, yourself), teams, the bot's
  Discord ID answer, the roster endpoint and the per-address topic limiter.
  Run it with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/voice_chat/probe.dm 300
```
