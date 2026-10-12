# Comparative collector benchmark

Run on Windows with pinned BYOND 516.1681 and a verified Python executable:

```powershell
& '<python.exe>' tests/gc_benchmark/run.py --byond-bin '<516.1681 bin>' --output '<fresh evidence directory>'
```

The fixture reuses the native memory ownership header, production qdel, pool helpers and actual collector. Only collector source changes between current checkout and immutable pre-PR3091 SHA `7cfa850bd9d2788dcbb9fd35f5c5915ccb528dd2`. Source hashes and compile/runtime logs are retained. No normal game startup, live server, storage imports or network port is used.

Soft-only, hard-only and repeated 30-hard/340-native-collected mixed batches run five times after a settled warmup for each workload. All qdel targets and weak collection are actual native BYOND objects. Artificial queue age avoids a thirty second wait while keeping production 300-candidate and 30-forced budgets unchanged. Assertions independently check a young target, the 29.9-second boundary, hard cap, timestamp-mismatched live identity, complete eventual drain and owner release.

The fixture includes the exact production PROCESS_TICK_CHECK macro. A negative tick allowance deliberately triggers its real early return; a second fire resumes the queue. Releasing the external live identity then waiting verifies native collectability after the collector's local stack returns. This is an isolated collector contract, not full process scheduler or sleeping-stack acceptance. Throughput runs use VERY_HIGH priority to measure a complete pass without scheduling noise and therefore do not model normal runtime budget returns.

CPU uses GetProcessTimes deltas around collector execution after preparation settles. Its interval includes file acknowledgement overhead. On the measured Windows host these CPU deltas were quantized in 15.625ms steps; small changes at that scale are not precise speedup evidence. Python wall time also includes polling and acknowledgement tick latency, so small differences must not be called improvements. The reported modulo elapsed_deciseconds field truncates to whole 100ms units; native timeofday itself can contain fractional deciseconds. Working-set RSS and private-byte snapshots are OS process measurements, separate from counts and timing; sampled peak storage is not a whole-game memory or OOM claim. Throughput setup and object allocation are excluded from measured CPU deltas. Variant order is baseline then current, with warmup, and does not randomize OS conditions.

Mutation controls change generated source only: `--negative-control budget-return`, `hard-cap`, and `candidate-cap` must each fail at their designated assertion. Run each into fresh evidence storage. These validate fixture sensitivity and do not alter production files.
