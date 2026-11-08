# Leader orders

```
python3 tests/leader_orders/run.py --byond-bin <pinned bin>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless. It checks that only leaders give orders, that an order reaches
allies in range but not enemies or distant allies, the cooldown, the whistle
bonus (strength, range and cooldown), the strength cap, expiry, and that order
state is never saved.
