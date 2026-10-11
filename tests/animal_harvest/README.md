# Animal harvest regression

Run with a verified Python interpreter and explicit BYOND 516.1681 bin path:

```powershell
& '<verified-python-executable>' tests/animal_harvest/run.py --byond-bin '<516.1681-bin>'
```

The runner compiles the production DME without its map or normal world startup,
then launches a small offline world in unique temporary storage under ignored
`data/animal-harvest-tests`. It copies only name configuration. Generated compiler
inputs/outputs are removed in `finally`; evidence logs remain for review.
Linux CI uses the downloaded pinned BYOND bin directory and `/usr/bin/python3`.

The fixture executes production yield construction, harvesting claims, post-wait
validation, sinew conversion, axe assembly and the actual map-storage object
save/load implementation. Wait adapters inject cancellation, revival, movement,
tool loss, corpse deletion, disconnected actors and recursive competing attempts.
Two cases additionally execute production `do_after` for successful completion
and movement cancellation. Network clients, normal AI/startup, medical experience
and inventory UI are excluded. Results do not establish full-server RAM usage,
production season behavior or graphical gameplay acceptance.

The baseline global controller can emit BYOND `BUG: Bad ref ... globals.dm:16`
diagnostics at startup before this fixture starts; normal DM exceptions are
separately recorded and fail the runner. This is not a clean full-game startup
claim. The bounded output assertion measures item count, not heap usage.

With Pillow, `preview.py --output <file.png>` validates each new item's effective
existing DMI state (including rotten variants), rejects blank/missing sprites and
renders a PR-review sheet. It never modifies game art. Upload the sheet to the PR,
verify its rendered attachment, then remove the generated local PNG.
