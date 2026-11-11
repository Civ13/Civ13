# Yeast bread regression

`run.py` compiles the production dough and oven sources with normal world
startup disabled and runs `probe.dm` in temporary offline storage. It checks
that plain or unrisen dough bakes into flatbread, that kneading pays five units
of yeast once, that dough rises only after its deadline, and that risen and
still-rising dough survive native disk round trips (the runtime deadline is
excluded and restarted after load). It also checks that flattening preserves a
partly consumed dough's reagent contents, including added water.

Run `run.py --source-check` for offline mutation-target validation, then the
pinned BYOND positive probe and each `--negative-control` choice
(`oven`, `payment`, `rising`, `persistence`, `load`, `flatten`). Output directories must be
empty. No production config/saves, client, Topic request or restart is used.
Pass `--compile-only` with the usual `--byond-bin` and `--output` arguments to
compile the isolated probe without starting DreamDaemon; this does not run assertions.
The probe sets deadlines directly instead of waiting five real minutes; it does
not establish map reachability of yeast or ovens or graphical acceptance.
