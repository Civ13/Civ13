# Hover name HUD

The human HUD shows the pointer target's public name near the top center of
the map, including items in visible inventory slots. All existing human HUD
styles share the same attachment. This is pointer feedback, not a click or
examine action. Moving onto empty space or a HUD control clears the text.
Human names use `get_visible_name()` so masks do not disclose `real_name`.

Enter, move and drag events update immediately. A matching exit clears the
target; an older exit cannot clear a newer enter. The existing human HUD
process revalidates a stationary pointer target, clearing deleted, moved,
contained or invisible targets on its next refresh. No timer or strong target
reference is added. HUD destruction and logout clear the label; reconstruction
starts blank. The UI is not saved, and its runtime guard forwards to inherited
export/import exclusions.

Run with pinned BYOND 516.1681:

```powershell
& '<verified-python.exe>' tests/hover_name/run.py --byond-bin '<BYOND-bin>'
& '<verified-python.exe>' tests/hover_name/run.py --byond-bin '<BYOND-bin>' --negative-control identity
& '<verified-python.exe>' tests/hover_name/run.py --byond-bin '<BYOND-bin>' --negative-control exit
& '<verified-python.exe>' tests/hover_name/run.py --byond-bin '<BYOND-bin>' --negative-control stale
& '<verified-python.exe>' tests/hover_name/run.py --byond-bin '<BYOND-bin>' --negative-control parent
```

The isolated native fixture executes production widget methods, weakrefs,
visible-name code and mouse callback bodies with a fake network-client boundary.
It uses real native view membership, locations, invisibility and screen atoms.
It closes its port at startup, rejects reopening, uses temporary storage and
exits without normal game startup. Negative controls must fail their intended
runtime assertion, not compilation. `--compile-only` never launches a daemon.
Wiring assertions separately check HUD attachment/life dispatch, logout and
both existing saver/loader runtime guards. This does not establish real client
mouse delivery, text rendering or full-game save/load acceptance.
