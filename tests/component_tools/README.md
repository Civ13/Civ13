# Component work tools

Run `scripts/check-component-tools.py` with Python and BYOND 516.1681. On Windows
use verified absolute Python, `--compiler` and `--runtime` executable paths.
Optional `--report` preserves the assertion summary.

The runner uses the recipe harness's startup isolation: actual game definitions,
no maps, world/controller startup disabled, temporary runtime/config storage,
bounded compiler/daemon execution and no production configuration or processes.
Only the fixture player's initialization, inventory drop and HUD updates are
adapted. Material constructors, assembly, deletion, stats and the current-format
world serializer execute production code. The fixed fixture checks all three
families, exact ingredient removal, duplicate callbacks, inaccessible/broken
inputs, quality bounds, wear transfer, handle capacity and speed bounds, global
material immutability, legacy defaults and native entry save/load round trips.

Run `scripts/check-recipes.py` separately for recipe registration and generic
stack consumption. These checks do not prove client interaction, every recipe
in every era, full-map save performance or long-running gameplay. No screenshots
are substituted by fixture output. `component-tools.yml` is a manual CI runner.
