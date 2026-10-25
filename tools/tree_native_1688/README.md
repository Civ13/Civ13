# Tree native Linux516.1688, exact shovel source

This controller is separate from production sources and frozen Windows helpers.
It requires real clean HEAD ef4ebf0c6e648f2c5ae330973c8bf8a55899a20f and tree
7053ffa0194dd1ae0c021218139af7247419870e, plus every pinned manifest byte.

Prepare only (read-only actual Git admission, no native runtime):

```sh
python3 -B tools/tree_native_1688/run.py --source /actual/exact-checkout --output /fresh/evidence
```

After explicit execution approval, add `--reviewed-native --byond-bin
/verified/byond/bin --byond-archive /verified/516.1688_byond_linux.zip`.
No installation/acquisition is performed by this CLI. The separate one-shot
workflow uses only pinned reviewed acquisition. Do not rerun consumed attempts.

Offline tests require exact input bytes, not native or actual Git:

```sh
TREE_TEST_SOURCE=/exact/source python3 -B -m unittest discover -s tools/tree_native_1688 -v
```

Every test installs the offline audit fence; mocked Git/process receipts are not
actual admission or execution evidence. Retained local preview inputs may be used
instead when running from the review packet. Native proof requires all twelve phases,
84/3/25 baseline checks (112 total), four exact controls and verified cleanup.

Successful phases retire only manifest-bound source copies or daemon binary copies
after cleanup and hashes; preserve compile originals, logs, hashes and synthetic
saves. Retirement is recorded, fixed-path and forbidden on failed/uncertain cleanup.
Never treat this synthetic engine-state fixture as real-client appearance,
whole-world recovery, natural cadence, performance or Windows guard evidence.

## Shovel candidate acceptance

The unchanged exact-candidate tree regression suite (21 tests) and Atlas catalog
freshness command run before any native work. Ordinary compilation is not native
shovel acceptance. The roundtrip probe adds 64 assertion evaluations: rejection
of 10 nonshovel/folded tools at two stages, plus all 11 open shovel types at two
stages with processing-cleanup and no-output checks. Existing mature-tree yield,
save/load and fresh-process reader checks remain. The fourth generated-only causal
control restores the former cutting-tool gate and must fail the first
`nonshovel tool preserves seedling state` assertion. Compiler/runtime errors,
timeouts, and cleanup failures never count as causal detection.

The one-shot branch is `codex/tree-native-1688-shovel-attempt2`, with the controller
commit's sole parent equal to the exact source HEAD above. This is an inactive
source proposal until separately reviewed publication creates that branch. No
workflow rerun, dispatch fallback, expanded resource cap, or relaxed cleanup gate
is authorized by this README.

## Unexecuted successor after failed shovel attempt 1

Adapter `tree-linux-516.1688-shovel-v2` supplies a real `/datum/species/human`
inside the generated `tree_tester/New()` fixture constructor. The original
production fixture skips human initialization; its first tool cleanup reached
`update_icons()` with null species in attempt1. No cleanup/icon/qdel method is
replaced or bypassed. All112 assertions and four controls are unchanged. Attempt1
remains failed and preserved; this fresh attempt2 proposal needs root review
before publication or execution.
