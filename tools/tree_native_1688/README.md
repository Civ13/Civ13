# Tree native Linux516.1688, exact e773 source

This controller is separate from production sources and frozen Windows helpers.
It requires real clean HEAD e773c2fae4b196ad6c7afc025235e90f488f7db8 and tree
4800aac2e81b45b6fb215bcf23f8ed3761186fe3, plus every pinned manifest byte.

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
instead when running from the review packet. Native proof requires all ten phases,
20/3/25 baseline checks, three exact controls and verified cleanup.

Successful phases retire only manifest-bound source copies or daemon binary copies
after cleanup and hashes; preserve compile originals, logs, hashes and synthetic
saves. Retirement is recorded, fixed-path and forbidden on failed/uncertain cleanup.
Never treat this synthetic engine-state fixture as real-client appearance,
whole-world recovery, natural cadence, performance or Windows guard evidence.
