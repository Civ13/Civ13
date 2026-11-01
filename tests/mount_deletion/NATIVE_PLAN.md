# Bounded native mount-deletion acceptance plan

Status: proposal only. No native fixture source, runner, workflow step or execution
is authorized by this file. Review the exact fixture/runner manifest separately
before an action-time authorized run. This source slice uses offline tests only.

## Source and environment

- Bind the immutable proposed head and unchanged source hashes in the evidence.
- Use the canonical BYOND pin/archive from tools/byond/version.json, currently
  516.1688, with verified archive identity. Historical 516.1681 memory/weakref
  runners and README counts are not acceptance evidence for this case.
- Reuse a reviewed current-pin isolated full-game fixture envelope with normal
  startup disabled. Review constructor/global dependencies before admission.
- Limit the fixture to an 8x8 single-level map, one synthetic human, two horses,
  one optional spawner and one optional observer datum. No real client/account,
  save data, live world, credentials or gameplay input is used.
- Require the existing runner's process-tree, private output and network controls;
  -close by itself does not establish network isolation. Stop if those controls
  fail. Do not alter OS/security settings or substitute another execution route.
- Keep the post-entry fixture runtime within 30 seconds; compilation has its own
  reviewed bounded deadline. Check the testing authorization window before launch.

## Cases

1. Establish the same reciprocal fields and turf placement as MouseDrop_T using
   production human/horse constructors. The mount gesture itself is outside scope.
   Call production qdel only on horse A. Require A's captured reference to resolve
   to null, the human to survive at the same turf, and riding/riding_mob to be
   FALSE/null. Observe existing spawner/mob registry cleanup without changing its
   implementation or deleting another mounted human.
2. Give A a stale rider reference while that human is reciprocally mounted on B.
   Delete A. Preserve the human's B link/flag and B's riding state exactly.
3. Delete A with no rider. Require ordinary cleanup without runtime errors.
4. Use the reviewed destroyed-event observer boundary to request recursive
   qdel(A), observe already-cleared matching human state, and establish a new B
   relationship. Require one actual cleanup and preservation of B after return.
   Do not create a new relationship to the already-retiring A.

Retiring-rider marker cases remain source-derived offline coverage in this slice.
Do not expand this plan into rider deletion, raw del, AI scheduling or GC tuning.

## Controls, receipts and limits

- A generated-copy omission of the three-line cleanup must fail specifically at
  the surviving human riding-state assertion. Compiler/runtime failures are not
  accepted negative-control success.
- Require zero unexpected runtimes and exact positive/negative assertion counts.
- Retain exact source/diff, engine/archive checksums, fixture/runner manifest,
  compiler/runtime logs, process cleanup receipts and every failed attempt.
- Tear down only fixture-owned resources; make no restart/deployment/live changes.
- Passing would establish these bounded deletion/state cases, not general rider
  handoff safety, rendering, save compatibility, performance or all deletion APIs.
