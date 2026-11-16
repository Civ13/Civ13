# Kept hives probe

Native probe for `code/modules/1713/kept_hives.dm`: swarms hanging near a
strong colony, shaking a swarm into an empty hive (no stings), growth and
stored comb with forage, dwindling without it, eating stores out of season and
dying out, spring swarming, cutting comb with and without smoke, and the
every-third-minute colony tick.

    python3 tests/ecology_spawning/run_linux.py . tests/kept_hives/probe.dm 300
