# Wildlife arrival timing

Native acceptance for the wildlife sub-tile walker (#3509): an animal using the
opted-in sub-tile walk must reach its target on the same schedule as the legacy
native `walk_towards()`.

```sh
source <byond>/bin/byondsetup
python3 tests/wildlife_arrival/run.py --byond-bin <byond>/bin
```

`run.py` appends `probe.dm` to a temporary copy of `civ13.dme` and runs it once
in DreamDaemon from a fresh output directory. It opens no client and listens
only on localhost. The probe walks a mosquito 8 tiles towards a target with
lags 1, 2, 3, 3.5, 4 and 5 ds, once with a still target and once with a target
moved 2 tiles at 1 s, first with the legacy walk and then with the sub-tile
walker. A run takes a few minutes, most of it Gaia start-up.

The run passes when, for every case:

- sub-tile arrival is within one server tick of legacy arrival,
- both walks enter the same number of turfs,
- the mean step over the first 8 tiles is no slower than legacy.

One exception: if the legacy walk had already arrived when the target moved,
the sub-tile reaction may land one step period later. A native step jumps the
whole tile at once, while the sub-tile step glides there over one period.

Measured on 516.1688 (tick 0.4 ds), native walk lag is in deciseconds, rounded
down to whole ticks, with a minimum of one (lag 3 steps every 2.8 ds). Before
the fix, the walker started one interval late and rounded each step up a tick.
On master that left it up to 7.6 ds late over 8 tiles (lag 3: 29.2 vs 22.4 ds).
`test_check.py` tests the checker offline, including those master numbers.
