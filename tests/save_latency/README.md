# Bounded admitted saver integration (draft)

`run.py --byond-bin <516.1681-bin>` stages the current admitted production saver,
loader, player reclaim and export-transfer contracts with isolated adapters.
The daemon uses repository-required `-trusted` in fresh temporary storage; the
fixture hides the world and refuses port reopening. No production files or
servers are used.
Use `--dense --verify-backup` for 20,000 direct scalar-only children, first and
backup saves, active restoration and a fresh-process backup restoration. The
normal fixture uses 1,000 children with typed associative payloads. Heartbeats
must make progress inside dense discovery; printed timings are observations,
not representative full-world latency acceptance.

Run `--scenario concurrent`, `--scenario movement`, `--scenario parent-deletion`,
`--interrupt`, and both `--negative-control yield|old-reader` separately. The
interruption case kills only its own temporary writer after invalidation and
checks rejected active files plus restoration of the completed backup.

The current transfer contract requires live, unchanged export frames. Unlike the
historical #3105 candidate, deletion or replacement of an active parent aborts
the generation and retains the completed backup. Tests assert this fail-closed
outcome, admission cleanup and backup graph recovery. A completed child's first
captured edge is retained across later movement; cross-level traversal excludes
an already captured movable, while cross-level saved-variable references refuse.
This is a conservative integration, not acceptance of the earlier detached-parent
rolling snapshot algorithm. Hooks, list copies, native writes and flushes are
still nonpreemptible, and snapshots are not atomic world transactions.

New world files advertise format 3: typed/sharded entries from version 2 plus
500-reference content chunks. Current readers still accept historical flat/text
and version-2 typed files. Old version-2 validators reject format 3 before world
mutation; the old-reader control compiles the immutable production loader from
75890d883190355e430f9958fd102864ee88429a to check that rejection. Direct small
version-2 exports retain text contents; dense version-2 exports fail explicitly.
The round-state generation format remains round-v2, independently of the level
file encoding. A downgrade requires retained version-2 generations; ordinary
rolling backups are eventually format 3 too. No automatic downgrade is provided.

The 20%-relative/8192-work policy uses sleep(0) below 80% global tick usage and
waits a tick at exhaustion. This is an experimental duty-cycle increase, not an
equivalent-budget optimization. It still needs representative native first-save,
backup-save, restoration and throughput/heartbeat comparison before readiness.

`--prepare-only` and `python3 -m unittest discover -s tests/save_latency -v`
check staging/hashes and effective mutation anchors only, without native runtime.
Dispatch `test.yml` at the exact published commit with
`save_latency_regressions=true` to run this suite plus current ordinary save and
operation-admission regressions. This remains draft pending those results and
representative acceptance. No live save, import, restart or deployment is covered.

The ordinary transfer fixture includes a version-3 checkpoint callback that moves
one paid item after the first transfer drain. Publication must reject it and
release every frame. Progress instrumentation follows the new coordinate writer
and wraps explicit sleeps without changing the 8192/20/80 policy. Explicit sleep
counts/times remain distinct from historical stoplag metrics. Native progress
clock and diagnostic-write-failure isolation checks run alongside this suite.

Current-master integration also runs protected-sleep and reference-failure
regressions with `protected_sleep_regressions=true`. The cross-level movement
probe requires one format-3 entry, one spatial parent, preserved scalar state,
and durable aliases resolving to the restored first capture. Its first-capture
mutation must reproduce the exact original duplicate-binding rejection. The
sleep diagnostic fixture deliberately bypasses only its target's first-capture
tracking to exercise the production duplicate guard and scalar failure snapshot;
this injected diagnostic case is not evidence of a production duplicate.
