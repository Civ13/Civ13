# Extraction pinned-master reconciliation

PR: https://github.com/Civ13/Civ13/pull/3082 (draft).

The initial reconciliation and its CI failures below are historical evidence at
`8a0bdc36b3c4907a26d9634445a7a75770866247`. See
[the focused harness follow-up](harness-followup.md) for the subsequent corrections
and their separate offline evidence. The original resolution patch is preserved.

Source merge: `c4585fabaf81e1357054b4527d71d4f3a2d8a0b2`.
Its first parent is the previous extraction head
`5aaed0a172aa3baa3fe604096cbbb8a00f519aac`; its second parent is pinned master
`99647037c70786a3c3944fcf5ae51b570b377f08`.
The later server-management foundation is not imported.

## Independent review

[manual-resolution.patch](manual-resolution.patch) is the complete Git remerge
diff for the source merge, including all nine conflicted files and ten additional
manual fixture/adapter updates. It includes the original conflict markers as
removed patch lines. Reproduce with:

```text
git -c core.abbrev=40 show --remerge-diff --format=fuller --no-color c4585fabaf81e1357054b4527d71d4f3a2d8a0b2
```

SHA-256: `eb3c6382857658ebe32f8e7b135fff94811a8645d918c1311362cdc6b3a0906f`.
The patch is 42,613 bytes. Review this alongside the automatic merge, rather than
treating imported master files as newly authored extraction behavior.
[files-from-previous-head.txt](files-from-previous-head.txt) inventories the
complete source-merge delta; [files-vs-pinned-master.txt](files-vs-pinned-master.txt)
inventories the extraction branch delta against the pinned base.

The reconciliation preserves both AGENTS additions, both sprite manifests,
extraction storage custody and master save-movement admission. The restore
wrapper keeps its optional policy/attempt binding, mutation reservation,
restart-intent checks, original failure and at-most-once transient release. It now
also retains master elevation, zone/spawn and roof restoration, area snapshot
invalidation and the persistence age floor, with players restored afterward.
All extraction module source files remain byte-for-byte unchanged from the
previous extraction head.

CI retains master's exact-archive compiler bootstrap, selection receipts and
offline baseline. Existing extraction/admission diagnostic success prerequisites
now reference that actual `compile` step. Their other admission clauses and
strict native version checks are unchanged. Prepared fixture receipts name each
generated source explicitly so controls do not assume a positional filename.
The save-movement projection interprets the extraction optional field lookup and
tests that extraction movement rejection still precedes hand assignment.

## Local evidence

Executor: Windows PowerShell, Git/GitHub CLI and CPython 3.13.1. GitHub access is
available. Installed BYOND file metadata reports 516.1688; no native executable
was invoked. The historical detached extraction candidate and playtest checkout
are preserved; implementation used an isolated task worktree.

[offline-checks.json](offline-checks.json) records the individual suites: 373
tests pass with no skips across the passing suites. Passing
suites cover extraction generation/map/compile-only boundaries and instances;
restore integration, profiling, sleep/cross-level guards; persistence date;
zone/roof/elevation contracts and packet preparation; save movement; reserved
lighting; CI policy; compiler bootstrap and toolchain contracts. Injected compiler
output is mocked evidence, not an actual compiler result.

Two additional Linux-oriented modules fail on this Windows executor:

- `test_byond_runtime.py`: one error in the synthetic successful identity read,
  with `Runtime identity file changed while reading`; two POSIX/privilege skips.
- `test_sprite_toolchain.py`: two errors around injected Linux `PosixPath` and
  the absent resulting receipt; two platform/privilege skips.

Those two test modules and the runtime identity helper are unchanged from pinned
master. Their failures remain recorded; runtime identity checks were not relaxed.
Native compiler, daemon, connected-client, manual and production acceptance were
not executed locally. Full offline logs remain in the task evidence directory.

## Remaining blockers and acceptance limits

1. Thoth's independent review of the complete manual-resolution diff and the
   resulting automatic merge is outstanding. This remains a draft.
2. Fresh ordinary PR CI must be assessed at the published head. Older green runs
   do not verify this merge. Master compiles with 516.1688, while retained
   extraction and persistence-admission runtime harnesses strictly require
   516.1681. The standalone extraction-instances lane retains its separate
   historical 516.1681 setup. A version mismatch in the main lane is a blocker,
   not permission to relabel historical evidence or loosen its checks.
3. Full-game startup, connected account/session interactions, equipment/workshop
   and vehicle behavior, representative save/restart/recovery and unresolved
   instance/travel/surface integration acceptance remain separate from offline
   fixtures. No readiness for deployment is claimed.
4. Surface census/private-home replica completeness, production restore provider
   and immutable reader, external ledger/custody, quarantine publication and
   host-level sole-writer ownership retain their existing incomplete/disabled
   boundaries. Ephemeral parties/account-private homes are unchanged.

Mall PR3118 can consume the reconciled extraction head after review; no mall
source or branch was modified. No merge to master, deployment, restart, security
policy change or admission relaxation is included.
