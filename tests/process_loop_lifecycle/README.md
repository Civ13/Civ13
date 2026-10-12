# Process loop lifecycle

Run with BYOND 516.1681:

```powershell
& '<verified-python>' tests/process_loop_lifecycle/run.py --byond-bin '<516.1681-bin>' --evidence-dir '<fresh-evidence-directory>'
```

The isolated native fixture compiles extracted production scheduler start/process/stop/recordRunTime and process started/may_run procedures. It closes its port, refuses reopening, and uses temporary storage without normal game startup. Fifteen assertions exercise repeated starts, stop/restart while the old invocation sleeps, active watchdog replacement, repeated denied admission, original deadline expiry, successful admission bypassing may_run, preserved started hooks, and the existing 20-entry runtime history limit.

Each start installs an identity token. Superseded invocations stop when they next wake; stop does not synchronously cancel a native sleep. The fixture checks scheduler cadence, not instantaneous zero sleeping invocations. Lazy denied-history expiry keeps one scalar deadline and clears history on the next admission query after expiry. Starting a successful run cancels the previous deadline, preserving its new history.

`--baseline` uses immutable commit `7cfa850bd9d2788dcbb9fd35f5c5915ccb528dd2`. Its expected five failures demonstrate duplicate cadence and old callbacks clearing successful history. Callback counters instrument only the historical spawn entry/exit, leaving its wait and cleanup unchanged. One initial denial plus 1,000 subsequent denials produced 1,001 pending callbacks; fixed source has zero per-denial callbacks. These counts are isolated retained continuations, not OS memory or whole-game latency measurements.

Run deliberate controls separately with `--negative-control token`, `--negative-control deadline`, and `--negative-control successful-run`. They remove token checks, postpone expiry on every denial, or remove the started deadline reset respectively. A successful control runner means exactly the expected assertions failed; it does not claim the mutated production behavior passed.

Evidence includes original production sources and hashes, extracted/adapted source, fixture, compiler/runtime logs, native result, HEAD and pre-generation dirty patch. Compilation requires zero errors/warnings; runtime errors and engine diagnostics invalidate every run, including controls. Full-game scheduling, subclass restart configuration and OS memory are outside this focused fixture.
