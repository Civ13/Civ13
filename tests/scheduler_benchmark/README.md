# Native scheduler admission benchmark

Run on Windows with BYOND 516.1681 and a verified Python path:

```powershell
& $PythonPath tests/scheduler_benchmark/run.py --byond-bin $ByondBin --output $FreshEvidenceDirectory
```

The runner compiles unchanged production `may_run()` from the checkout and immutable pre-PR3091 source `7cfa850`. It uses fresh native processes, public-free temporary state and closed ports. One warmup per variant is excluded. Five paired repetitions per workload run in deterministic shuffled order: 50,000 healthy admissions, then 1,000, 10,000 and 50,000 denials. Tests assert admission decisions, expiry recovery, healthy history preservation and network closure. Compiler warnings and native diagnostics fail the run.

Each result retains the source hashes, compiled source, dirty patch, native logs and 10 ms private-byte samples. CPU is Windows kernel plus user process time for the entire run, including startup, admission, delayed callbacks and shutdown. It is not a high precision admission-only measurement. Settled private bytes are the median samples during the half-second after expiry verification. Waiting does not force native allocator pages to return to Windows. `report.json` reports every run plus medians and ranges, excluding warmups.

Existing `tests/process_loop_lifecycle` tests instrument callback counts separately and prove loop-token, deadline and successful-run regressions; this benchmark deliberately leaves both production admission bodies uninstrumented. Full-game behavior is checked separately under `tests/game_loop_benchmark`. These bounded tests do not establish player/client acceptance, production latency, long-term RSS or OOM stability.
