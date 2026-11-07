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

The fixture also runs `armor.dm` against the production armor bench. It checks
exact costs and excess stock, all three stages, unchanged vest stats, research
and era gates, cancellation, concurrent entry, removed/changed inputs, actor or
bench movement, lost research, persistence identity changes, destruction and a
nested serializer round trip. Armor slot cleanup uses an explicit fixture human
adapter; real `transfer_held_item_to` and material identity checks remain active.

For current-pin Windows, use `run_windows.py --byond-bin <516.1688-bin>
--output <fresh-directory>`. It reuses the existing canonical 1688 owned-Job
facade and no-socket supervisor, retains logs/source hashes and runs no maps.
`--negative-control armor-consumption` omits payment in generated source;
`--negative-control armor-research` removes the research guard. Each must fail
its named assertion. A supervisor rejection is a failed run, never a pass.

`dedicated.dm` covers the dedicated benches in `dedicated_workbenches.dm`:
one-step retargeting (stored items returned, refused while busy or for an
unknown recipe), the weapon assembly bench (tool heads refused, head material
and condition kept, retargeting returns the output) and the fletcher's bench
(floor loading of bare shafts only, one head kind, exact batch costs,
cancellation, bolts and sharpened flint). On the 516.1688 Linux run for this
change it passed; the three armor era failures (`armor late era bypass` and its
two follow-ons) also fail on master and predate it.
