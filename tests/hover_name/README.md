# Hover name HUD

The human HUD shows the pointer target's public name at the top-left corner of
the map, including items in visible inventory slots. A black inline backdrop
fits the text only; clearing or an empty name removes both text and backdrop.
All existing human HUD
styles share the same attachment. This is pointer feedback, not a click or
examine action. Moving onto empty space or a HUD control clears the text.
Human names use `get_visible_name()` so masks do not disclose `real_name`.

Inventory slot art resolves only the current body's registered, displayed slot
to its actual equipped item. The item must belong directly to that body and be
displayed at the same screen location. Other bodies, closed/nested containers,
generic HUD controls, empty slots and arbitrary `screen.master` references do not
grant a name. The existing world LOS/read guard still checks the resolved item.
Direct item hits and stationary revalidation require the same visible registered
slot, equipped item identity and matching screen location. A pouch item left in
the client's screen list after hiding its slot cannot retain a hover label.
Separate weak pointer-origin and item references keep exits tied to the correct
enter event. Removal/drop, slot replacement and body/UI changes clear old text
on the existing HUD refresh, even if a dropped item is now visible in the world.

Enter, move and drag events update immediately. A matching exit clears the
target; an older exit cannot clear a newer enter. The existing human HUD
process revalidates a stationary pointer target, clearing deleted, moved,
contained or invisible targets on its next refresh. No timer or strong target
reference is added. HUD destruction and logout clear the label; reconstruction
starts blank. The UI is not saved, and its runtime guard forwards to inherited
export/import exclusions.

The inventory correction is covered by offline source execution in the existing
`los_context` baseline suite. Native mouse delivery and pixels remain unverified.
The legacy native runners below still assert516.1681 and were not run for this
repair; they require current-pin preparation before supplying new native evidence:

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
Own-body enter/move/drag and exit are covered explicitly, including masked
identity, transparent/invisible rejection and a remote-camera round trip.
It closes its port at startup, rejects reopening, uses temporary storage and
exits without normal game startup. Negative controls must fail their intended
runtime assertion, not compilation. `--compile-only` never launches a daemon.
Wiring assertions separately check HUD attachment/life dispatch, logout and
both existing saver/loader runtime guards. This does not establish real client
mouse delivery, text rendering or full-game save/load acceptance.

`run-weakref-save.py` adds an actual disk-backed production saver/loader round
trip using the real weak-reference and widget methods. It injects historical v2
and flat cache entries carrying an old native ref, checks restored own-name
hover and durable identity/inventory/location, and preserves a live replacement
cache. `--negative-control export` removes both export guards for this field;
`--negative-control import` removes its import guard and must lose the restored
own-name label. `--prepare-only` generates sources without native execution.
The same `--byond-bin` argument is required; CI runs all three cases alongside
the existing hover suite. This remains an injected network-client boundary.
