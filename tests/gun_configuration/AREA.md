# Disposable native firearm area

This opt-in area is not included by `civ13.dme`. It runs normal game startup
with native guns, attachment tools, magazines and a repair bench in temporary
storage. It does not change gun action waits or compatibility checks.

```powershell
./tests/gun_configuration/run-area.ps1 -ByondBin '<BYOND 516.1681 bin>' -Visual -TimeoutSeconds 600
```

Supply an absolute path to a trusted BYOND installation. The launcher never
starts a client; close the client you manually open when your screen turn ends.
Visual mode opens the selected game port: use a local, appropriately firewalled
test machine. Connect the local client to the printed loopback address. After readiness,
use Local Verification > Enter gun test area. The SVD starts with a PSO-1:
check that it is unloaded, equip a screwdriver, use Field Strip, remove the
PSO-1, then use the rail and red dot sight on the held gun. Examine before
and after. A cleaning kit and repair bench are provided for native service.
The optional condition control explicitly assigns artificial wear only to
an area gun held in the active hand. It does not perform maintenance.

The launcher disables hub listing and configured banner lookup in its copied
configuration, and the area disables configured webhook/remote-ban hooks.
This is local testing, not production operation. Use an authorized exclusive
screen turn for graphical capture. The launcher owns and bounds its daemon,
removes unique compilation outputs and retains temporary logs/readiness JSON.
Without `-Visual`, the world exits after area construction.

Observed at merged PR3081 commit
`60b8cf9937617d62c4cc01f82bf32401559b84f4`: area compilation had zero errors
and warnings; the existing isolated gun regression passed 99 assertions.
Genuine graphical footage records an empty SVD, PSO-1 removal, rail/red-dot
installation and native Examine, plus explicitly labeled 60% wear setup.
The footage does not establish completed cleaning, bench repair or firing.
Normal startup logged `Bad ref` in `DecRefCount(DM New)` and an unexpected
nslookup diagnostic. These remain unresolved runtime acceptance limitations;
area readiness is not a clean full-game runtime pass.

## Capture editing

Keep the exact build, item/tool requirements, selected actions and visible
before/after outcomes captioned. Use focused zooms and highlights for native
menus, held parts and Examine text. For future clips, inspect frame changes
and aggressively trim navigation or compress static waits; retain action
starts and completions at readable speed. Label every compressed wait with
its speed or omitted elapsed duration. Conventional editing must not invent
gameplay or turn artificial condition setup into a maintenance result.
