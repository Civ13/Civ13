# Chemical registration audit

`run.py` compiles production sources with normal world startup disabled and
runs `probe.dm` in temporary offline storage. It initializes the real reagent
and reaction lists and fails on duplicate reagent IDs (a later type silently
replaces the earlier one), reaction products or inputs without a registered
reagent, inherited base-reaction inputs, and wrong ID lookups. It also mixes a
few repaired reactions in a real beaker by running the chemistry process body.

Kevlar and nitrocellulose reactions are allowlisted in the probe because their
`on_reaction` spawns objects or clears the holder instead of leaving a reagent.

Run `run.py --source-check`, then the pinned BYOND 516.1681 positive probe and
each `--negative-control` choice (`base`, `latte`, `parent`, `product`,
`sterilizine`). Output directories must be empty. No production config/saves,
client, Topic request or restart is used. This does not establish balance or
map reachability of any reagent.
