# Zombie city probe

`native_probe.py` is developer evidence, not a CI suite. It compiles a
temporary copy of `civ13.dme` with `maps/EFT/crossroads_mall.dmm` selected and
`native_probe.dm` appended, runs it once headless in DreamDaemon and checks
`result.json`:

- every loot table and tier at research ages 0, 5 and 9 (no guns at age 0,
  only age- and tier-allowed items, nothing saved);
- the horde stays inert until a block is registered and rejects unknown densities;
- zombies appear around a clientless anchor body, out of its sight;
- they chase and bite it, a kill lowers the block's total, gunfire noise turns
  idle zombies toward the sound, and with no anchor left they fold back into
  the block count.

```sh
source ~/byond-516.1688/byond/bin/byondsetup
python3 tests/zombie_city/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir
```

A run takes about three minutes.
