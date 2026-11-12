# Admin spectating

`code/modules/admin/verbs/admin_spectate.dm` gives admins and moderators three
Admin-tab verbs:

- **Hide Ghost** toggles whether their admin ghost is visible. A hidden ghost is
  at maximum invisibility, its ghost image leaves every client, and players'
  Follow/Jump to Mob lists leave it out. The setting stays on for every later
  aghost until switched off.
- **View As Player** shares a player's camera. The admin's ghost follows the
  player, and each tenth of a second the admin's client mirrors the player's
  eye, view size, camera offset, screen (HUD, plane masters, darkness and
  line-of-sight masks) and client images, and copies the body's sight flags. A
  transparent shield over the mirrored screen swallows clicks. The view follows
  the player into a new body (death, ghosting) and ends when the admin moves
  their ghost, follows someone else, re-enters a body, loses staff rights,
  clicks the label at the top of the screen or uses **Stop Viewing Player**.
  The player map panel has a View button for the same thing.

Tests:

- `test_admin_spectate.py` (offline CI suite `admin_spectate`): wiring, staff
  guards, the click shield, the stop conditions, the hidden ghost reapplied on
  aghost and the player map button.
- `probe.dm`: developer evidence in DreamDaemon with the shared Linux runner;
  checks the hidden ghost, the follow-list filter, the mirror's list sync and
  the view's failure paths.

```text
python3 -I -B tests/admin_spectate/test_admin_spectate.py
python3 tests/ecology_spawning/run_linux.py . tests/admin_spectate/probe.dm
```

Not verified: no client can connect in a headless run, so the mirrored screen
in Dream Seeker, chat (the player's private messages are not mirrored) and the
feel of the 0.1 s sync are unchecked.
