# Research scheduler resume correction

Run the bounded offline check from the repository root, using a verified Python:

```powershell
& '<verified-python>' -B -m unittest discover -s tests/research_scheduler -v
```

`test_resume.py` translates a small, explicit vocabulary from the actual research
`fire`, snapshot reset and shared `finished` procedure. It preserves those source
branches and statement order and rejects unrecognized instructions. It replaces
callbacks, budget reads, DM iteration and native subtraction with Python adapters.
It is source-derived algorithm evidence, **not native DM execution or compilation**.
The production macros and both process entry points are checked as source contracts.
The existing shared `PROCESS_LIST_CHECK` macro remains unchanged.
CI registers only this offline suite under the existing introduced-test or
explicit extensive-regression guard; this patch adds no native regression runner.

Cases cover one-entry budget returns through eventual tail service, no repeated
prefix within a logical pass, budget return at the last entry and fresh next-pass
discovery, deletion while pending, null/deleted-only snapshots, empty populations,
live-list additions/removals, callback deletion and a caught analysis exception.
Controls restore the ephemeral iterator, omit consumption, or insert the old
deleted-entry `continue`; each demonstrates its specific broken trace. A fourth
control reads the actual audited research source from immutable master
`9db2b2f42a5fbbb0bdd49d50a2672da6111a7709`: the shared finished procedure sees its
empty scheduler snapshot, normalizes the budget return to completion, and the next
dispatch repeats the first bench while the tail is never reached.

Research's production registry registers each bench once in `New` and removes it
in `Destroy`. The offline iterator adapter uses a stable visit sequence and models
the previously established native last-match subtraction contract. It does not
establish native mutation-during-iteration, callback reentry or client behavior.
An externally removed but still-live bench remains in the owned snapshot, just as
it did in the former temporary copy. Additions enter the next logical pass.

## Scheduler source review

- `relayProcess` resets only a null snapshot, then calls `process()`.
- `process()` and `fire_as_member()` propagate `finished(fire())`.
- `finished()` retains a nonempty snapshot only on the early-return sentinel.
  An exhausted early result becomes normal completion and releases the snapshot.
- Research now consumes each entry before its budget check, including QDELETED
  entries and caught callback exceptions. It uses the existing object-loop pattern.
- Research setup remains LOW priority and the ten-second schedule is unchanged.
  A logical pass can span dispatches; each eligible bench advances once per pass.

## Bounded native plan - awaiting parent review and coordination

No native compiler, daemon, game, OpenDream, sockets or heavy checks are launched
by these offline tests. Do not run the commands below before coordination.

1. Review this exact diff, record the target commit and isolate a fresh temporary
   directory. Use native BYOND **516.1681**, matching `.github/workflows/test.yml`.
   Stage a tiny 3x1x1 fixture, no production map, normal world initialization,
   configuration, saves, shell bridge or outbound adapters. Use only counted stub
   benches and injected analysis callbacks.
2. Extend the existing `tests/process_loop_lifecycle` extraction pattern to include
   the actual research `fire/reset_current_list`, production macros, `finished`,
   `process`, `fire_as_member` and `relayProcess`. Keep the production removal macro
   verbatim. Compile with `-max_errors 0`; require 0 errors and 0 warnings.
3. Start after one normal tick, anchor `run_time_tick_usage` to `world.tick_usage`,
   then set a negative allowance to force the actual budget return after one entry.
   Assert `[a]`, pending `[b,c]`, then `[a,b]`, pending `[c]`, finally `[a,b,c]`, null
   snapshot and normal completion. Inject a budget return only at the final entry
   as a separate case; assert exactly one completed relay dispatch and no new pass
   in that dispatch. Cover both scheduler and member entry points.
4. Repeat the offline cases with real qdel/GC/nulls, including deleted first/last
   entries, deletion of a pending peer by a callback, addition between resumes,
   live-list removal, self-deletion and caught exceptions. Counters must show no
   duplicated prefix and no service of newly added benches until the next pass.
   Run the audited baseline and each mutant separately; require the intended
   failure, retaining other failures without relabeling them as success.
5. Adapt the established fixture's closed-port/refused-reopen/client rejection
   controls, with separate zero-listener OS verification. After approval only,
   use `-trusted -invisible -close`, a 20-second run deadline and the existing
   bounded process containment approved by the parent. Capture compiler/runtime
   versions, source hashes, dirty patch, full diagnostics and exact assertion
   counts. Require no engine diagnostics and confirmed process exit.
6. Reuse the existing shared lifecycle/removal fixtures only if this integration
   exposes an unresolved common-semantics concern; do not launch benchmarks or a
   full game to validate this source correction. Full-game and connected-client
   evidence remain separate acceptance, with screenshots/steps if requested by
   the parent. This plan does not grant native or runtime permission.

## Follow-up aggregation concerns

Cleanables and ping are deliberately separate source changes. Their correctness
needs persistent per-pass aggregates and a completion path before the final-entry
budget return: shared `finished()` correctly releases exhausted snapshots and
cannot know that subclass post-loop work was skipped. Do not solve that by changing
the common macro or by retaining an empty snapshot. Cleanables additionally needs
bounded deletion work that remains represented by nonempty pending state. Ping
must consume all skipped/disconnected clients as well as queried clients, keep
partial sums/counts across resumes and publish an average only on completion.
Those follow-ups await the parent's review of the research snapshot correction.
