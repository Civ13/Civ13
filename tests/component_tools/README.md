# Component work tools

The Linux CLI requires the canonical archive, installed bin directory and a new
evidence directory:

```sh
python3 scripts/check-component-tools.py --byond-bin "$PWD/BYOND/byond/bin" \
  --byond-archive "$PWD/BYOND/pinned.zip" --output /tmp/component-positive-new
```

The manual workflow acquires the checked canonical manifest pin (currently
516.1688). The shared verifier binds the archive and four installed members,
rechecks before compiler and daemon, and requires one exact clean compiler result.
The compiler/daemon limits remain 180/90 seconds and the workflow remains manual
with a ten-minute job limit. Positive, consumption and runtime-save omission
controls retain separate fresh output directories. Generated source, logs and
identity/error receipts survive failures; optional `--report` also copies the
assertion summary. No current-pin native run was performed for this source port.

Previous 516.1681 and Windows CLI examples are historical. Bare executable
selection is no longer an active unverified alternative to archive identity.

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
