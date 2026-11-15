# Signal fire tests

- `test_signal_fires.py`: offline source contracts (DME order, the campfire hands leather and cloth to the signal code, plume sprite state, cooldown not saved). CI suite `signal_fires`.
- `probe.dm`: native probe of the compass bearing (including fires straight north or south), who sees a signal (range, level, roof both ways, asleep or blind), cloth and leather use, the cooldown and fire pits. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/signal_fires/probe.dm 300
```

Sprites: `python3 tests/sprites/create_signal_smoke.py [--preview sheet.png]` rewrites `icons/effects/signal_smoke.dmi`.
