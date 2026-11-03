# Player action keybindings

Players can use **OOC > Keybindings** or the top-level **Keybindings** menu in
the lobby or during play. Choose hotkey or typing mode, then an action. Change
replaces that action's aliases in that mode; Unbind clears them; Restore defaults
restores its original aliases. Restore all defaults resets both modes. Changes
save immediately in the existing account preferences, across reconnects/restarts.
Cancel leaves the assignment unchanged. To swap keys, unbind one action first.
Restoring one action refuses conflicts; restoring all always succeeds.

The catalog covers prone, aiming mode, sights/drone/tank gun, running, movement
mode, defense and secondary intents, tactics, facing, buckling, quick equip,
holstering and directional attacks. Actions still call their original verbs and
their existing gameplay checks. Both original mode defaults and aliases remain.

The finite key list supports plain keys, Ctrl, Shift and Ctrl+Shift. Typing mode
only permits Ctrl and Ctrl+Shift combinations plus its pre-existing F and Space shortcuts.
Movement, held activation, chat, spell, targeting, menu and help shortcuts remain
reserved. Movement and held activation retain their original release handlers;
this feature adds no held state. Applying bindings changes only the 52 named
action slots and does not set focus, replace macro sets or reset movement.

Saved records use `mode/action/key` strings in the existing flat-list preference
codec, with `NONE` for an explicit unbind and no record for defaults. Invalid,
duplicate, oversized or conflicting saved records reset action keys to defaults.
No saved value becomes a command, macro ID, release handler or arbitrary winset.

Extend `action_keybinding_catalog()` with a discrete action and at most two
default aliases per mode, and add its two named slots in each skin macro set.
Review the candidate/reservation policy if fixed macros change. Held actions
need a separate lifecycle design; do not insert them into this discrete catalog.

## Checks

```powershell
dm.exe civ13.dme
python -m unittest discover -s tests/action_keybindings -p test_keybindings.py -v
python tests/action_keybindings/run.py --output <fresh-directory> --byond-bin <pin-bin> --compile-only
python scripts/agent_preflight.py all --write
```

The eight offline checks audit the frozen original macro contract (including all
movement/release/focus macros), catalog/skin agreement, reserved keys, typing
keys, parenthesized DM membership guards with an omission control, persistence,
reconnect/body-login wiring, application boundaries and prompt cancellation.
They are registered in the bounded offline CI baseline. CI compiles the full
game; this PR adds no native job admission. The frozen macro fixture is a source
contract, not a runtime recording, and tests never read historical Git objects.

The native fixture projects the complete production policy, skin application
and text preference IO into a 1x1x1 world. It injects the client/winset boundary
and unrelated preference helpers, rejects clients and reopening the port, uses
temporary SQL storage, and reuses the current-pin owned-Job facade. Its manifest
records production and generated hashes. It is not a full-game/client test.

The initial Windows probe on 2026-11-03 exercised rebind/unbind, aliases, mode
isolation, skin parameters and production text save/load. It then failed a
malformed-record assertion, exposing an unparenthesized `in` guard; the corrected
guard is covered offline. Its log also showed a transient startup loopback
listener and hub login before `world/New`, missed by the sampling supervisor.
That run is failed evidence. Further Windows runtime launches are refused until
a no-socket startup envelope is available. The final fixture can be prepared or
compiled; its runtime and conflict-omission control remain unexecuted.

Real DreamSeeker delivery/rendering, menu focus, body transitions and reconnects
remain unverified. No live Gaia process, save, credentials or security settings
are part of these checks.
