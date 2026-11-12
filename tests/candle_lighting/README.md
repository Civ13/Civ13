# Candle lighting and open flames

`isflamesource()` in `code/game/objects/items/weapons/cigs_lighters.dm` is the
shared check for "can this light a wick". Each flame source overrides
`/atom/proc/is_open_flame()`; electric lights and glowsticks set
`open_flame = FALSE`. Candles and smokables use it.

Offline source checks:

```bash
python3 -m unittest tests/candle_lighting/test_flame_source.py
```

Native probe (after `bash scripts/cloud_byond_setup.sh` on Linux):

```bash
python3 tests/ecology_spawning/run_linux.py . tests/candle_lighting/probe.dm 300
```

On Windows:

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/candle_lighting/probe.dm
```

`probe.dm` builds real lights, fires and structures and checks which count as
an open flame, then lights candles and lard candles from a held or placed tiki
torch, a campfire (which must not take the candle) and another candle, and
checks that electric flashlights, unlit torches and the candle itself do not.

Not established: the click path in a real client.
