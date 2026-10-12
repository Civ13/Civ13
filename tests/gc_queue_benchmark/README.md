# GC queue representation benchmark

Run `run.py --byond-bin <516.1681-bin> --output <temporary-result.json>` with a verified Python interpreter. The runner builds a standalone native BYOND fixture in temporary storage, closes its listening port, and cleans the fixture afterward. It does not compile or launch Civ13.

The baseline mirrors the existing chronological associative ref-string/timestamp list, including subtraction at enqueue and front Cut at consumption. The candidate uses parallel ref-string/timestamp arrays, a current-timestamp map, and a head cursor. Consumed slots are nulled immediately. Compaction occurs after more than 4096 consumed slots when at least half of the allocated array is consumed; empty queues reset immediately. No queue stores strong datum references.

Correctness checks cover the 300-entry scan and 30-hard-delete budgets, expired/new entries, superseded ref keys, a live datum whose timestamp differs from its queued ref timestamp (controlled model of ref recycling), and compaction/reset. It does not force the engine to reuse a particular numeric reference.

Measured workloads sustain 300 enqueues and up to 300 dequeues per round for 200 rounds at initial backlogs 300, 10,000 and 50,000. Unique keys and repeated keys are measured three times. Timings use operating-system file-write timestamps from markers immediately before and after each measured loop, exclude initial backlog construction, and include enqueue and drain work. Synthetic ref strings isolate queue representation from locate/del costs. Native datums are used in correctness checks.

Results establish representation behavior in bounded synthetic churn only, not full-server performance, memory pressure, OOM remediation, or gameplay acceptance. The fixture intentionally models the existing timestamp guard; it does not improve its same-timestamp collision contract.

The slot-bound assertion uses the initial pending backlog, not distinct current-map keys: superseded entries still occupy string-only pending slots until scanned. This candidate does not deduplicate enqueue slots. Consequently an enqueue stream repeatedly superseding keys faster than the 300-entry drain budget can grow the pending queue despite a small current map. Consider this additional retention and changed queue-count semantics before integration.


## Measured decision (Windows, BYOND 516.1681)

Three-run medians for 200 rounds of 300 enqueues plus bounded drain, excluding initial backlog construction:

| Initial backlog | Ref reuse | Baseline ms | Candidate ms |
| --- | --- | ---: | ---: |
| 300 | Unique | 169.97 | 197.84 |
| 300 | Repeated | 110.90 | 94.06 |
| 10,000 | Unique | 1483.57 | 1426.52 |
| 10,000 | Repeated | 214.49 | 192.22 |
| 50,000 | Unique | 5505.43 | 5634.38 |
| 50,000 | Repeated | 1586.59 | 2065.52 |

Retain the existing production representation. The candidate shows no consistent improvement and is slower at the largest tested backlog. With repeated refs and initial backlog 50,000, the baseline drains to zero slots while the candidate ends with 59,900 allocated slots and only 300 current-map entries. A future alternative would need deduplicated bounded pending storage before integration. These timings include native list/map operations and file-marker overhead, not production locate/del costs or concurrent game work.

The isolated build reported zero errors and zero warnings; correctness checks passed. Results are observations on one machine and workload, not a general BYOND performance guarantee.
