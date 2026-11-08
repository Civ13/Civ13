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
