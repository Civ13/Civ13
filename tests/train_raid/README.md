# Train Raid offline suite and probe

`build.py` generates `maps/EFT/train_raid.dmm` and its layout manifest from the
two Dagger map studies in `tests/dagger_map/`, docking one shuttle in each
berth and adding the mode objects described in
[docs/train-raid-mode.md](../../docs/train-raid-mode.md).
`test_train_raid.py` regenerates the map, parses the checked-in DMM and checks
the geometry the mode relies on. `native_probe.py` appends `native_probe.dm`
to a temporary DME with the map selected and drives one headless round under
DreamDaemon; it is developer evidence, not CI.

```text
python3 -I -B tests/train_raid/build.py --check
python3 -I -B tests/train_raid/test_train_raid.py
python3 tests/train_raid/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir
```

Neither the suite nor the probe is real-client acceptance.
