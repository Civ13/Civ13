# Native runner sweep

`scripts/native_runner_sweep.py` runs every native BYOND runner under `tests/` (files named
`run*.py` or containing `native` that take `--byond-bin`) on the pinned compiler. The
`Native runner sweep` workflow runs it every Monday and on demand.

The workflow installs Pillow for the sprite audit; install it locally too.

```bash
bash scripts/cloud_byond_setup.sh   # once; installs the pin into ~/byond-<version>
source ~/byond-516.1688/byond/bin/byondsetup
# region_relay needs the i686 Linux rust-g 3.0.0 library; fetch and verify it once:
curl -fsSL -o ~/librust_g.so https://github.com/tgstation/rust-g/releases/download/3.0.0/librust_g.so
echo 'b92f18e19667148628b3f45dbdf58765eab18daa14d1d28db8dfe83211165b45  '"$HOME/librust_g.so" | sha256sum -c
BYOND_ARCHIVE=~/byond-516.1688/pinned.zip RUST_G=~/librust_g.so python3 scripts/native_runner_sweep.py \
  --byond-bin ~/byond-516.1688/byond/bin --jobs 3 [--only name ...] [--output report.json]
```

Without `RUST_G`, region_relay fails on Linux and the sweep reports it as a new failure.

The sweep gives each runner a fresh `--output`/`--evidence-dir` path, `--byond-archive`
(from `BYOND_ARCHIVE`) and `--rust-g` (from `RUST_G`, the i686 `librust_g.so` of rust-g
3.0.0) when it takes them. `manifest.json` holds:

- `runners`: extra arguments (`args`), a longer `timeout` (seconds), or `serial: true` for a
  timing-sensitive runner that must run alone after the parallel batch.
- `skip`: runners the sweep cannot run (Windows only, or they need a mode, packet or
  live service), with the reason.
- `known_failing`: runners that already fail on master, with the first error. They still
  run. The sweep fails on any other failure, and names known failures that now pass so
  they can be removed from the list.

When you fix a known failure, delete its entry in the same PR.
