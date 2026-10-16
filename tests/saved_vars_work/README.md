# Saved-variable name union work

`get_saved_vars` previously unioned `name` after every eligible full-export
variable. The candidate unions it once, at the same point after the first
eligible variable. It still calls every runtime-exclusion hook in original
order and reads each current/initial value in the same order. Partial-export
parsing and the native saver/loader are unchanged. No cache or persistent field
is introduced; the flag exists only for one call.

Run from the repository root using BYOND 516.1681:

```powershell
& '<verified-python>' tests/saved_vars_work/run.py --byond-bin '<516.1681-bin>' --output '<fresh-parity.json>'
& '<verified-python>' tests/saved_vars_work/run.py --byond-bin '<516.1681-bin>' --negative-control order --output '<fresh-order.json>'
& '<verified-python>' tests/saved_vars_work/run.py --byond-bin '<516.1681-bin>' --negative-control exclusion --output '<fresh-exclusion.json>'
& '<verified-python>' tests/saved_vars_work/run.py --byond-bin '<516.1681-bin>' --negative-control repeat --output '<fresh-repeat.json>'
```

The fixture imports the actual baseline/candidate procedure, current runtime
exclusion bodies and dirt override. Minimal type declarations replace game
constructors; native vars/initial/list/type semantics run in a 4x4x1 offline
world. It closes its port and rejects reopening, uses temporary files and
terminates the process within 90 seconds. Compilation requires zero errors and
warnings. Full logs, dirty patch and source/probe hashes accompany each result.

Seventy-one cases compare ordered keys and sampled values across datum, object,
item, structure, wild, metadata, covers, mob and dirt classifications; changed
values, exact per-instance allowlist text, duplicate/associated allowlist keys,
empty lists, runtime exclusions, dirt additions and return-list isolation.
Fresh twins compare stateful hook order/mutations, including all-excluded and
only-one-eligible cases. List/cycle values are checked by retained identity;
matrices by coefficients because native matrix reads return copies. This tests
selection equivalence, not disk serialization or full game constructors.

Generated-source controls move name before the first changed eligible key,
omit exclusions, or restore redundant unions. The first two must fail behavior;
the last must preserve behavior but fail work counts. Counts are instrumented
separately from uninstrumented timing bodies. Local initial results: 71 cases,
zero behavior/work failures; controls detect 4, 38 and 42 failures respectively.
The item fixture performs 92 baseline name unions versus one candidate union.

Optional `--benchmark` runs three full-export types after 200 warmup calls per
variant, five paired groups with alternating order, 1,000 calls per variant and
group. Engine `world.timeofday` elapsed deciseconds exclude inter-group sleeps.
These are isolated native wall times, not CPU cycles or verified opcode counts.
Comparative timing is pending an owner-approved resource window. Do not claim a
speedup from operation counts alone: the candidate adds a branch per eligible
variable. No live latency, memory or server throughput improvement is established.
