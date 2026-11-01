# Harvest fixture input accounting - source-only proposal

This correction is prepared above published `011931e0a0482239628d7031196be572b13c2788`.
It has not been pushed, compiled or run natively. Main retains review and retry
authorization. The existing animal runner and shared retention helper remain the
only proposed route; no cap is bypassed and no alternate runner is added.
The reviewed scope is a Linux trusted checkout. Windows native execution remains
unverified; publication and native approval are still pending.

## Exact required inputs

`civ13.dme` includes `code/names.dm`. Its 157 eager global `file2list` initializers
reference 146 unique files, including the spaced `file2list (...)` declaration.
They run before the fixture's replacement `world/New`. `file2list` calls
`return_file_text`, which errors on missing/empty files, so staging only a few
name families would change initialization. No other `config/names/` reads occur
in game DM source. The complete exact list is the 146 `config/names/` records in
`tests/flax_processing/required-inputs.json`.

The old recursive copy staged 150 files. Four have no eager reference and are
excluded: `first.txt`, `first_female_afrikaans.txt`, `last_cherokee.txt`,
`last_inuit.txt`. Names/data choices are preserved; no production initializer is
stubbed or edited.

The 146 name paths are checked against the pinned source hash, declaration count,
exact distinct path set, normalized byte counts and SHA-256 fingerprints. The
actual source bytes are preserved and their size/hash bound before copying.
The existing literal 18-byte `# Offline fixture\n` config is the 147th input.
It has its own fingerprint. Inputs are expected to stay unchanged; prelaunch
and post-phase checks reject persistent changes, including equal-length changes.
The checks reject symlinks; they do not generally reject hard links. These are
fingerprint checks, not immutable/read-only mounts or an atomic filesystem snapshot.

The private review packet's 146 name payloads have mixed line endings: 135,796
raw bytes, or 134,930 after CRLF-to-LF normalization. Including the fixed config,
the packet payload is 135,814 raw bytes; the normalized equivalent is 134,948.
Do not assume a Linux checkout or the packet contains only LF bytes. Each run
records and preserves its actual source bytes after normalized validation.

The shared flax manifest additionally lists a loose recipe input. Harvest's
`hide_recipe_probe.dm` embeds that same recipe with a single-quoted resource
declaration, then reads the resource variable. It needs no extra filesystem copy.
The stager checks those source anchors and fails for a string-path replacement.
The shared manifest's recipe fingerprint is already stale at the published head;
this patch neither changes it nor weakens the shared full-plan validation. The
harvest-specific validator checks exactly its name dependency instead.

## Bounded accounting

The shared helper already supports separately enumerated required inputs. With
no map supplied, the old harvest call counted every file toward 128; this caused
the observed prelaunch failure. Its existing flax caller uses a separate fixed
input inventory plus the 128-file reserve. Harvest now supplies its own exact
147-input map through that same API for both compile and runtime phases.

| Bound | Published harvest | Prepared correction |
|---|---:|---:|
| Required loose inputs | 150 copied names + minimal config, counted as outputs | 146 pinned names + minimal config = 147 |
| Generated/evidence/other file reserve | All files share 128 | 128 non-input files, unchanged |
| Evidence-tree derived file ceiling | 128 | 147 + 128 = 275 |
| Normalized input bytes, including config | Not separately recorded | 134,948 |
| Review-packet raw input bytes, including config | Not separately recorded | 135,814 (mixed line endings) |
| Cross-platform input byte ceiling | Not separately recorded | 153,265 including CRLF expansion |
| Combined evidence-tree byte ceiling, including inputs | 512 MiB | 512 MiB, unchanged |
| Text/generated input per file | 2 MiB | 2 MiB, unchanged |
| Each DMB/RSC artifact | 256 MiB | 256 MiB, unchanged |
| Each captured stream/combined log | 16 MiB | 16 MiB, unchanged |

The four declared generated files in the checkout remain additional existing
owned paths: two source files at 2 MiB each and two binary files at 256 MiB each.
Thus the declared whole-case observed accounting bound is 279 files and 1,028 MiB across the evidence
tree plus those four paths. The checkout/toolchain itself is outside that case
inventory. As before, observations and post-compile artifact checks are not OS
filesystem/RSS/CPU quotas; native writes can overshoot between checks. Linux
descendant/socket cleanup remains unverified in limited scope.

Unlisted files under `runtime/config` fail. Missing, symlinked, resized or
fingerprint-changed required inputs fail. Other outputs still count toward 128,
and all input bytes count toward 512 MiB. The bounded plan is written before
copying, so partial staging preserves a complete observed inventory without
falling back to the obsolete 128-all-files retention limit.

The runtime working directory and DMB/RSC copies move from the evidence root to
its `runtime/` child, matching the shared helper's configuration namespace.
Native diagnostics, metadata and synthetic saves reside there; phase logs and
receipts stay at the evidence root. Existing timeout, interruption, early-exit,
external-receipt and no-deletion tests are adapted to those paths.

## Offline controls and preserved failures

`test_input_accounting.py` runs through baseline suite `harvest_inputs` without
starting a process. It checks exact source/input sets, maximal CRLF bytes,
omitted source/duplicate manifest/input changes, recipe resource provenance,
missing/symlinked/equal-length-changed/unlisted staged inputs, the 128-output limit,
and combined input-plus-output bytes. Negative preflight controls assert zero
`Popen` calls. The post-phase mutation control uses an explicit in-memory fake
child and proves a zero-exit adapter cannot turn changed inputs into a pass.
Partial-copy failures preserve the planned map and complete observed inventory.

Historical evidence remains unchanged:

- [First CI run](https://github.com/Civ13/Civ13/actions/runs/41269099687): Atlas
  provenance failure before native compilation; corrected separately by the
  reviewed pin and sole generated line-reference refresh.
- [Published-head CI](https://github.com/Civ13/Civ13/actions/runs/41269442467): 27
  offline groups/896 tests passed; both 516.1688 compiles passed with zero errors
  and warnings; output budget rejected 150 copied names before DreamDaemon/Popen.
  Runtime assertions did not execute. The original logs and zero-launch proof
  remain in the private CI evidence packet.

## Native scope for Main review

Normal publication of the combined branch still selects only the introduced
`tests/animal_harvest` native suite, with extensive regressions off: one normal
game compile (300 seconds, 15-minute step), one complete fixture compile (120
seconds), and one `DreamDaemon` run (60 seconds), 516.1688 in an 8x8x1 plating world
without DMM includes. No mutation-control runs or other native suites are added.
The same production-source harvest/tanning/synthetic-save fixture and competing
action case are included. The tall-grass counter is the native message oracle;
other message guards retain source-only coverage.

The proposed daemon argv is unchanged except the owned binary's `runtime/` path;
cwd/state-directory becomes that same owned child. Arguments retain loopback,
`-nowebclient`, `-trusted`, exact tested commit and runtime log. There is no live
Gaia, production-save, full-cleanup assertion, deployment or restart operation.
No publication, workflow dispatch or native retry is performed by this proposal.
