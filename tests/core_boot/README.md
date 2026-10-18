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

Native core-boot and fresh-process lighting runs still need separate authorized
BYOND 516.1681 execution and graphical acceptance. The runtime exception's native
file/line receipt also needs that verification. This WIP harness is not wired
into CI; offline success does not establish a native or gameplay pass.
