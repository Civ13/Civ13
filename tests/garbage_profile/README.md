# GC deletion profiling regression

Use a verified Python interpreter and BYOND 516.1681:

```
<python> tests/garbage_profile/run.py --byond-bin <BYOND-bin> --output <fresh-evidence-directory>
<python> tests/garbage_profile/run.py --byond-bin <BYOND-bin> --negative-control bound
<python> tests/garbage_profile/run.py --byond-bin <BYOND-bin> --negative-control cleanup
<python> tests/garbage_profile/run.py --byond-bin <BYOND-bin> --negative-control forced
<python> tests/garbage_profile/run.py --byond-bin <BYOND-bin> --negative-control clock
```

The launcher copies complete production garbage/profile sources and reuses the existing memory-ownership fixture adapters and collector regressions. It starts no normal game systems, closes/refuses the listening port and keeps native storage in a fresh directory. Production ordering, lifecycle and 300/30 budgets are exercised alongside the new counters. Mutation controls change generated copies only. A successful control exit means its intended assertion failed, with zero compile warnings or runtime/engine diagnostics.

Evidence retains copied sources and hashes, exact HEAD/dirty patch, compiler log, native daemon/runtime logs and result. Injected clock starts test total/max and one-midnight arithmetic; a real sleep tests yielded cleanup. The 10,000-update wall-clock microbenchmark is coarse isolated context and cannot establish full-game overhead or performance. See [profiling limits](../../docs/gc-deletion-profile.md).
