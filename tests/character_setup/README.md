# Character setup window

- `python3 -B -m unittest discover -s tests/character_setup -p 'test_*.py'`:
  offline source contracts (owner-only window, declared actions, value checks,
  every trait placed in a category).
- `python3 tests/ecology_spawning/run_linux.py . tests/character_setup/setup_probe.dm`:
  runs the window's data and trait actions on the pinned engine without a client.
- Screen behaviour: `tgui/src/interfaces/CharacterSetup.test.tsx`.

None of these is a check in a player's game client.
