# CM-SS13 ports

```
python3 tests/cm_ports/run.py --byond-bin <pinned bin>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless. It checks the round-start location text, balloon alert timing and
client guards, round-end facts (kill credit, first blood, top lines, a real
death reaching the death hook, announcing once), canopy shelter warmth, the
holiday calendar dates and opening a holiday gift.

The second batch adds checks for the megaphone speech range, glowsticks
(lighting, no switching off, burning out), container labels, the display case
(storing, key locking, taking back), the alarm tripwire (friends pass, strangers
trip it, the rattle cooldown), rally flags strengthening leader orders, the
codebook (ten distinct codes per side, kept all round, given to leaders only)
and the emote panel's list.

The third batch checks bipods (fitting, bracing prone or against a wall ahead,
unbracing on the move), the empty-gun ammo count, floor exercise limits and
fatigue, and the lockbox (first key sets the lock, wrong keys fail, blocked
storage while locked, beating the lock off). The escape menu needs a real
client and is not covered here.

The fourth batch checks the roll of the fallen (one entry per death, team rounds
only), dog tags (dead bodies only, one set per body, comrade and enemy counts),
commander medals (rank, side, citation and per-round limits), the weapon light
(lit only in hand), the gun sling (caught onto the shoulder only when knocked
down), the motion detector's contact list and the rangefinder report.

The fifth batch checks the typing bubbles (separate speech and emote sprites,
upright when lying down, cleared once the owner cannot type, not saved),
triage tags (four colours, kept through icon rebuilds, removable, not saved),
drag trails (only a dragged, bleeding body leaves one smear per tile), the four
signal smoke colours and the new-player marker's handling of missing clients.
