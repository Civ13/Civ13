# Core-boot compile and offline controls

The active runner requires the canonical BYOND pin from `tools/byond/version.json`.
It accepts no historical engine selection or fallback. Older engine results remain
historical evidence; they are not compatibility requirements after the pin advances.

Run the focused offline controls with an approved Python interpreter:

```powershell
py -3 -B -m unittest discover -s tests/core_boot -p test_runner.py -v
```

These tests use fake processes and synthetic logs. They retain phase exit/timeout,
runtime exception source/line, diagnostic, lighting quiescence, source-control and
generated-file cleanup regressions. They do not launch a compiler or DreamDaemon.
The former legacy-only main runtime entry is retired; version-independent phase
and assertion helpers remain covered by offline controls.

The CLI only generates and compiles source variants with exact Linux identity:

```sh
python3 -B tests/core_boot/run.py --byond-bin "$PWD/BYOND/byond/bin" --byond-archive "$PWD/BYOND/pinned.zip" --compile-only --output /tmp/core-boot-current
```

Both `--byond-archive` and `--compile-only` are required. The runner verifies the
reviewed canonical archive and installed compiler/daemon/library members through
`tests/world_save/current_runtime.py` and `scripts/byond_runtime.py`, then rechecks
identity immediately before compilation. It requires one exact compiler banner
and a clean summary naming the generated artifact. Missing identity, an old or
wrong engine, diagnostics, bad exit, changed files or timeout fail without fallback.
The manifest loader and source compile gate also require the canonical compiler.

Use an empty output directory. `--negative-control runtime`, `--lighting-load`
and `--lighting-restart` compile their generated source variants only. They do not
run a negative control, save, restore, client or daemon. Compilation has the existing
600-second deadline. Receipts retain the canonical version, manifest/input/control
hashes and identity checks; generated source/binaries are cleaned on failure too.

The existing CI step still selects three compile-only variants only when a PR
introduces executable `tests/core_boot` files or the extensive option is enabled.
This revision introduces no test path or native admission. The step's 32-minute
limit and seven-day allowlisted evidence retention are unchanged. A skipped step
does not establish compiler or runtime acceptance.

`ready_for_review` is still outside the workflow subscription and ordinary selector
actions. That separate event expansion is not included. Do not enable extensive
or other native fixtures merely to test this source revision.

Current-pin native boot, connected-client and saved-world acceptance remain
separate work under their existing owners. No old-engine runtime lane is required.
