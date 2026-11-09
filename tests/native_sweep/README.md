# Native runner sweep

`scripts/native_runner_sweep.py` runs every native BYOND runner under `tests/` (files named
`run*.py` or containing `native` that take `--byond-bin`) on the pinned compiler. The
`Native runner sweep` workflow runs it every Monday and on demand.

```bash
bash scripts/cloud_byond_setup.sh   # once; installs the pin into ~/byond-<version>
source ~/byond-516.1688/byond/bin/byondsetup
BYOND_ARCHIVE=~/byond-516.1688/pinned.zip python3 scripts/native_runner_sweep.py \
  --byond-bin ~/byond-516.1688/byond/bin --jobs 3 [--only name ...] [--output report.json]
```

The sweep gives each runner a fresh `--output`/`--evidence-dir` path and `--byond-archive`
when it takes them. `manifest.json` holds:

- `runners`: extra arguments (`args`) or a longer `timeout` (seconds) for one runner.
- `skip`: runners the sweep cannot run (Windows only, or they need a mode, packet or
  live service), with the reason.
- `known_failing`: runners that already fail on master, with the first error. They still
  run. The sweep fails on any other failure, and names known failures that now pass so
  they can be removed from the list.

When you fix a known failure, delete its entry in the same PR.
