# CM-SS13 ports

```
python3 tests/cm_ports/run.py --byond-bin <pinned bin>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless. It checks the round-start location text, balloon alert timing and
client guards, round-end facts (kill credit, first blood, top lines, a real
death reaching the death hook, announcing once), canopy shelter warmth, the
holiday calendar dates and opening a holiday gift.
