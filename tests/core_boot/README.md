# Core boot harness checks

Run the focused offline tests from the repository root:

```powershell
py -3 -B -m unittest discover -s tests/core_boot -p test_runner.py -v
```

These tests launch no compiler, DreamDaemon, game, port or network connection.
Fake subprocesses exercise the actual phase runner, including PASS followed by
nonzero exit, timeout after PASS, missing load output and successful two-phase
completion. Every phase must exit cleanly within its own deadline before another
phase starts or any positive/negative-control receipt is accepted.

The generated runtime control throws a unique exception only from the fixture's
own beaker during its chemistry phase. Its expected failure must agree with the
exception receipt's phase, generated source filename and exact throw line, and
every diagnostic must identify that same control. Unrelated errors invalidate
the control even if the intended marker is also present. The fixture intercepts
only this expected marker; ordinary errors retain their normal failure handling.

Lighting quiescence uses the existing typed overlay process's processing flag,
retained current_list and batch_index as well as the live queues and TOD worker.
The offline state controls evaluate the actual side-effect-free DM return
expression through a restricted Boolean/member/comparison syntax adapter. They
cover the old queue-only false-idle state and exhausted batches, but do not prove
DM compilation, native scheduling, rendering or heap behavior.

Generate and compile a fixture without starting DreamDaemon:

```powershell
py -3 -B tests/core_boot/run.py --legacy-fixture-5161681 --byond-bin C:/BYOND/bin --compile-only --output C:/evidence/core-boot-default
```

Use an empty output directory. Add `--negative-control runtime` or
`--lighting-load` to compile those generated variants. Compilation requires
an explicitly selected toolchain, exit zero and zero errors/warnings, with a
600-second deadline. `--legacy-fixture-5161681` retains the historical 516.1681
banner check and Windows/Linux support, without claiming archive identity.
Omitting a mode or combining modes fails before generation or compilation.

For current Linux compile-only checks, select the reviewed archive explicitly:

```sh
python3 -B tests/core_boot/run.py --byond-bin "$PWD/BYOND/byond/bin" --byond-archive "$PWD/BYOND/pinned.zip" --compile-only --output /tmp/core-boot-current
```

This path reuses `tests/world_save/current_runtime.py` and
`scripts/byond_runtime.py`. It requires exactly 516.1688, verifies the pinned
archive and installed compiler/daemon/library members, and rechecks identity
immediately before compilation. It requires one exact compiler banner and a
zero-error/zero-warning summary for the generated artifact. Wrong platform,
archive, member, version, diagnostic or identity changes fail without falling
back to legacy mode. `runtime-identity.json` records passive member identity;
it is not a native runtime observation. Current mode requires `--compile-only`:
this slice does not admit a current DreamDaemon run.

Compile-only returns before runtime staging, config copying or daemon launch;
it preserves compile logs, source hash and control location, then removes the
generated source and binaries. It does not verify an expected runtime failure.
Input hashes and the runtime-control location are written before compilation,
including when compilation fails or times out. Metadata distinguishes the actual
checkout commit/tree from the CI event's head SHA; the latter never relabels the
checkout. Probe, runner, DME, selected lighting/control inputs and generated
control sources have SHA256 digests.

The existing CI build job selects the offline checks and these three compile-only
variants when a PR introduces executable tests/core_boot files, or when the
existing extensive regressions option is enabled. Later edits alone do not select
the suite. The step has a 32-minute cap for three sequential 600-second compiles.
An upload step runs after an actually started check, including failure, and
retains its offline log, checkout identity and selected compile metadata/logs
for seven days. Its explicit file allowlist excludes configs, binaries and runtime
files. The three existing compile-only commands explicitly select the current
archive and retain `runtime-identity.json`. Their selection condition, deadlines
and number of compiles are unchanged. Skipped checks do not request an artifact.

`ready_for_review` is not subscribed or an ordinary selector action. Adding it
to both would admit introduced native suites, while existing label gates can
also admit runtime work. That event change requires a separate scope review;
the current workflow events, selector and runtime fixture gates are unchanged.

Native core-boot and fresh-process lighting runs still need separate authorized
BYOND 516.1681 execution and graphical acceptance. The runtime exception's native
file/line receipt also needs that verification. Native runtime execution of this
WIP harness is not wired into CI; offline checks and compile-only success do not
establish a native runtime or gameplay pass.
