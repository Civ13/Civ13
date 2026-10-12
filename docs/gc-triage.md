# GC outcome triage

The collector's queue is not evidence of physical deletion. On pinned BYOND
516.1681, an ordinary queued atom can disappear after its last strong owner
releases it; a retained target remains eligible for forced deletion after the
30-second grace period. Timestamp mismatches protect reused identities.

This follow-up extends deletion profiling's first 128 type rows plus one
overflow row. Cleanup and forced-delete timing keep their existing counters.
Outcome fields have these meanings:

| Field | Observation |
| --- | --- |
| `enqueued` | Added to the queue, with no claim of deletion. |
| `queue_absent` | Ref was absent when an expired record was examined. This cannot distinguish native collection from an earlier explicit deletion. |
| `queue_stale_identity` | A live ref had a different retirement timestamp; it was preserved. |
| `collection_failed` | An ordinary queued target remained at eligibility. Counts attempts, not unique objects. |
| `forced_requested` | Forced deletion was explicitly requested through the hard-delete queue hint. |
| `immediate_requested` | The immediate hard-delete hint requested deletion. |
| `forced_deleted` | A forced-delete call returned with its target physically gone. |
| `forced_incomplete` | A forced-delete call returned while its target remained. |
| `forced_error` | A forced-delete call threw; the original exception is propagated. No success is recorded. |
| `direct_deleted` | Normal finalization or cleanup physically deleted the target. |
| `pooled_retired` | Finalization placed the retained target in its pool. |
| `unchecked_handoff` | The self-collection hint was accepted without tracking physical disappearance. |
| `let_live` | Cleanup explicitly kept the target alive. |

`GC Outcomes` requires Debug rights. Repeated failures and first/last failure
times identify types worth investigating without storing offenders. The pending
sample copies at most 64 ref strings, type strings and timestamps without
locating targets. Ref-to-type metadata stops at 1,024 entries; untyped absent
records go to overflow and the dropped-admission count is visible. Metadata is
released when its queue record is processed. A paused collector can keep these
bounded scalars while its queue waits. No extra target ownership is introduced.

`GC Inspect Owner Field` also requires Debug rights. Supply a pending target ref,
the suspected owner's ref and one field. Rights and queue identity are checked
again after the prompts. The old `GC_FINDREF` automatic world scan is removed.
Existing unrelated legacy reference tools remain outside this bounded path.

The reference inspection result reports status, matches, visited slots and
truncation. Its limits are 256 slots and 32 list traversal entries, with cycle
detection. A partial inspection cannot establish that no other owners exist.
It does not discover proc arguments, engine references or unselected fields.
An inspected target is held only during the synchronous inspection call.

The design is informed by the public TG collector at
[`49afd5fd7cbf9de60ce81419a9bc97947fc55dc9`](https://github.com/tgstation/tgstation/blob/49afd5fd7cbf9de60ce81419a9bc97947fc55dc9/code/controllers/subsystem/garbage.dm),
which separates collection failures from requested hard deletes. Civ13 uses its
legacy process scheduler and native deletion paths rather than TG's subsystem.

Tests use isolated production procedures and pinned BYOND, temporary storage and
closed/refused ports. They establish classification and retained-reference
limits, not production memory improvement or whole-game latency.

Run `tests/gc_triage/run.py --byond-bin <516.1681-bin>` with a verified Python
interpreter. `--negative-control` accepts the targeted `triage-*` controls in
the shared launcher. The new suite has its own introduced-test CI guard;
existing broad regression groups remain opt-in.
