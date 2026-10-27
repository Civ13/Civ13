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

Tall grass uses the existing grass-cuttings material: cut either tall-grass
object with a sharp tool, then activate two held cuttings to make one crude
twine. The twine already gives a flint axe one quarter of normal durability.
Harvesting removes the plant without changing its floor; ordinary uprooting and
burning remain available. The agent's existing guarded `gather` action admits
both tall-grass types with its existing sharpened flint requirement.

The prepared tall-grass cases call each variant's production `attackby`, checking
two cuttings, one existing twine, plant retirement, unchanged floor, competing
and repeated claims, knife versus raw flint, cancellation, tool loss/blunting,
plant or actor movement, deletion, disconnection and unconsciousness. The lock
is explicitly excluded from persistence. Entry and completion also reject
stunned actors, changed hands, tools left in inventory or nested in a bag, and
movement to another adjacent tile. Production `do_after` cases additionally
inject movement, stun and hand switching during a real wait. The substantive
cases and adapters live in `tall_grass_probe.dm`, included and called by the
existing fixture; its new executable path selects this registered suite on PRs
without changing the CI workflow. Client, inventory setup and wait adapters
remain fixture-only; these added cases have not been compiled or executed yet.

The baseline global controller can emit BYOND `BUG: Bad ref ... globals.dm:16`
diagnostics at startup before this fixture starts; normal DM exceptions are
separately recorded and fail the runner. This is not a clean full-game startup
claim. The bounded output assertion measures item count, not heap usage.

With Pillow, `preview.py --output <file.png>` validates each new item's effective
existing DMI state (including rotten variants), rejects blank/missing sprites and
renders a PR-review sheet. It never modifies game art. Upload the sheet to the PR,
verify its rendered attachment, then remove the generated local PNG.
