# Crewed airships

Offline contracts: `python3 scripts/ci_baseline.py unit --suite airship_hull --output /tmp/airship-hull.json`.

Native airship voyages (pinned BYOND, no live listener, no real save):

```
python3 -B tests/ecology_spawning/run_linux.py . tests/airship_hull/voyage_probe.dm 300
```

This exercises the actual hull and cargo round-trip, crew deck positions,
collision-free arrival footprint, journal removal, and blocked-sky recovery.
It does not connect two live BYOND clients or shards.
