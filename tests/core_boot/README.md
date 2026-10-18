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
py -3 -B tests/core_boot/run.py --byond-bin C:/BYOND/bin --compile-only --output C:/evidence/core-boot-default
```

Use an empty output directory. Add `--negative-control runtime` or
`--lighting-load` to compile those generated variants. Compilation requires
BYOND 516.1681, exit zero and zero errors/warnings, with a 600-second deadline.
Compile-only returns before runtime staging, config copying or daemon launch;
it preserves compile logs, source hash and control location, then removes the
generated source and binaries. It does not verify an expected runtime failure.

The existing CI build job selects the offline checks and these three compile-only
variants when a PR introduces executable tests/core_boot files, or when the
existing extensive regressions option is enabled. Later edits alone do not select
the suite. The step has a 32-minute cap for three sequential 600-second compiles.

Native core-boot and fresh-process lighting runs still need separate authorized
BYOND 516.1681 execution and graphical acceptance. The runtime exception's native
file/line receipt also needs that verification. Native runtime execution of this
WIP harness is not wired into CI; offline checks and compile-only success do not
establish a native runtime or gameplay pass.
