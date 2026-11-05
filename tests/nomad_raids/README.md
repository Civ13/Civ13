# Nomad raids fixture

```bash
source <BYOND>/bin/byondsetup
python3 tests/nomad_raids/run.py --byond-bin <BYOND>/bin
```

The runner compiles the production sources with maps and ordinary start-up
removed, then runs `probe.dm` on a 40 x 40 outdoor test level with the pinned
BYOND build. It needs every assertion to pass and no runtime errors.

Covered: spawn-site rules (roofed, occupied), nearest-edge choice and skipping
edges too close to hide behind, loot worth, cooldown expiry and reload from
the file, the walk to the target planned from home and handed out in short
legs, the march following players who moved away, the walk home planned
from where the party stands, party size cap, unsaved raiders with weapon and bag, loose gear already lying
near the leader not counting as tribute until it is laid at their feet (or as
a trader's payment), tribute ending
the parley and limiting loot to the tribute, an attack starting the assault,
carrying loot, a fallen raider dropping loot, weapon and bag, removal dropping
loot, and the real controller loop marching to an empty target, turning back
and despawning every raider; and an island target: no walking route, a
water start, every member on an unsaved raft, landing ashore, paddling back
out and leaving no raft behind.

Not covered: fights with real players (clicks need a started round and a
client), crate opening, and visibility to real clients.
