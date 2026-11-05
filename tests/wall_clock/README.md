# Wall-clock jumps after a freeze

`scripts/gaia-host` can freeze dd.exe while nobody is online. BYOND does not
replay missed ticks, so `world.time` resumes where it stopped while
`world.timeofday` and `world.realtime` jump ahead (verified with SIGSTOP on
516.1688: a 40 s freeze advanced world.time by 1.5 ds and timeofday by 41 s).

`run.py` compiles `code/_helpers/wall_clock.dm` and the midnight rollover from
`code/_helpers/time.dm` into a small fixture and checks multi-day elapsed time,
rollover counting and the schedule shift. `--negative-control rollover|shift`
must fail; `--live-freeze 70` (Linux) suspends the fixture with SIGSTOP and
expects exactly one logged jump.

```bash
B="$HOME/byond-516.1688/byond/bin"
python3 tests/wall_clock/run.py --source-check
python3 tests/wall_clock/run.py --byond-bin "$B"
python3 tests/wall_clock/run.py --byond-bin "$B" --negative-control rollover
python3 tests/wall_clock/run.py --byond-bin "$B" --live-freeze 70
```
