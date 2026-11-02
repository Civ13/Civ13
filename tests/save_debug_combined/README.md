# Combined moving-human and debug-lossy recovery fixture

This is a separately reviewed, isolated synthetic test. It enables
`CIV13_HUMAN_SPATIAL_EXPERIMENTAL` in its generated DME and retains the existing
debug-lossy writer/fresh-reader, exact marker/audit and seed-backup checks. A
named synthetic human receives a headless-only movement authority seam. A
separate counter records an active-transaction capture on debug attempt two
and a later movement pulse while that operation remains active. The fresh
reader checks the writer's captured tile, zero movement offset, art offsets,
and backpack/nested pen, in addition to the audited leaf-animal omission,
saved nested-list alias and cycle, unchanged live list, item, box, reference
and seed backup. This does not test a connected
client, Gaia, every possible omitted type or live game continuity.

The writer's capsule and reader's restored tile are compared by the controller;
generation, all omission audit rows and the retained four-file synthetic seed
remain separately checked. False/missing handoff, post-handoff movement,
restore position, nested inventory, marker or seed bytes must fail. This
revision also tests moved/detached destinations, including two actual debug
saves that change the selected animal after round-state writing and require
the final audit to refuse publication with unchanged seed and backup bytes.
The controls passed in native run 41366597994 on head `1e0cca0a`; that result
does not establish native results for later source changes. Fixture injection occurs only in the
staged source, with exact anchors that fail on
drift. It neither changes the production movement predicate nor claims that
its headless seam proves real-client behavior.

Execution envelope: the existing Linux controller's one compile
and two sequential processes; 120 seconds per phase, 360 seconds combined
native deadline, 1 GiB address-space limit per process, 256 MiB file limit,
sampled 256 MiB aggregate output, 8 MiB logs, bounded inventory and up to ten
seconds cleanup per child. The process sees its fixture-only working tree and
minimal environment; the runner verifies the exact pinned 516.1688 archive,
executables and libraries before each child. The proposed hosted binding uses
`debug_combined_only=true` with the other four manual selectors false, and
requires the exact reviewed head and fixture-scope digest before provisioning.
It installs existing i386 dependencies with bounded `sudo apt` commands,
downloads and verifies the pinned official archive, and performs no bootstrap
game compile. It then invokes this controller once; the manual job has a
25-minute outer timeout. A PR changing the shared workflow also selects the
existing automatic moving-save matrix and normal CI, whose native processes are
separate from this manual fixture. Conflicting manual selectors fail before
provisioning. The binding remains subject to review. Loopback/no-port
checks are not an OS-level egress sandbox, and sampled directory size is not a
hard aggregate disk quota. No production save or credential is used.

The current recovery prototype only admits a still-resolvable, moved,
clientless, empty simple-animal leaf after a matching capture fault, and uses a
fresh owned attempt. A null or destroyed child, a human or other movable, a
child with contents, stale handles/changed location, an omitted associative
key with a non-null value,
unverified backup, changed owner or repeated fault is refused. Clientless does
not prove absence of player association. The recorded live Gaia fault has no
child identity, so this fixture cannot show that this case is recoverable.
Nested-list reference support passed in the same native run. Broader debug-lossy
continuity needs type-aware saved-graph omission/replacement
including other incoming references, bounded exact audit and fresh
candidate/reader verification; it must preserve retained entities and old
generations. That broader mechanism does not yet exist here.
