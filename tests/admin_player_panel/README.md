# Admin player panel

`code/modules/admin/player_panel_pages.dm` builds the two staff pages: the
player list (verb **Player Panel**) and one player's panel (**Show Player
Panel** and every PP link). Both share `admin_panel_css()`.

- `test_admin_player_panel.py` (offline CI suite `admin_player_panel`): the
  verb and Topic wiring, what moderators and mentors may not see, escaping of
  player text, and the list's search, state chips and column sorting run in
  Node with a stub DOM (skipped without Node).
- `native_probe.py` + `native_probe.dm` (developer evidence, not CI): compiles
  the game with the probe appended, runs it once in DreamDaemon with no client
  and checks the real pages for an admin, a moderator and a mentor. It writes
  `players.html`, `players_mentor.html` and `panel.html` for screenshots.

```bash
python3 -I -B tests/admin_player_panel/test_admin_player_panel.py
python3 tests/admin_player_panel/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir
```

Not covered: a real Dream Seeker window, and the actions behind the links
(they are the same links as before, handled by `code/modules/admin/topic.dm`).
