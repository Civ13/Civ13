# Region travel carry probe

`native_probe.py` is developer evidence, not a CI suite. It compiles a
temporary copy of `civ13.dme` with `native_probe.dm` appended, runs it once
headless and checks `result.json`:

- packaged food and drink, a bruise pack, a crowbar, a helmet and a full
  magazine can travel;
- a loaded gun, a sipped can, a bitten cracker, a bandage subtype, a backpack
  and a magazine with a foreign round cannot;
- a payload with an unloaded gun and a partly emptied magazine decodes, and
  overfull magazines or storage items are refused;
- the rebuilt character holds the same items, with the gun still unloaded and
  the magazine holding exactly the rounds that travelled.

```sh
source ~/byond-516.1688/byond/bin/byondsetup
python3 tests/region_carry/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir
```
