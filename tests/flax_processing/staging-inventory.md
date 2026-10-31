# Required inputs and bounded generated evidence

This is the source-only correction to the attempt-2 staging failure at
`4ce68ba68e55fa879817cf2e9f772586919b677a`. It has not been compiled or run natively.
Production DM, include order, native arguments and workflow selection are unchanged.

## Required name files

`civ13.dme` includes `code/names.dm` before world startup. That file has 157 plain
global `var/list/... = file2list(...)` initializers, referring to 146 unique name
files. These initializers still execute when the fixture disables normal
`world/New`, `global_init.New` and global-controller startup. The
`file2list` implementation in `code/_helpers/type2type.dm` calls
`return_file_text` in `code/_helpers/files.dm`, which reports missing/empty files.
Thus keeping only the default human's three name lists would not preserve startup.

The manifest includes the spaced `file2list ("config/names/last_afrikaans.txt")`
declaration and repeated references only once. Four of the old 150 copied files
have no initializer reference and are excluded: `first.txt`,
`first_female_afrikaans.txt`, `last_cherokee.txt`, `last_inuit.txt`. Existing
initializer choices are preserved, including the female Afrikaans variable's
reference to `first_male_afrikaans.txt`; this fixture does not repair name data.

`required-inputs.json` pins those 146 files plus the recipe input explicitly read
by the probe, `config/crafting/material_recipes_global.txt`. It binds the canonical
name-source hash, declaration count, exact path set, text byte counts and SHA-256
fingerprints. CRLF-to-LF normalization is used only for cross-platform checkout
fingerprints. Each run binds and copies the actual source bytes unchanged, records
their actual size/hash, and verifies the copied bytes before each process launch.
Missing, changed, linked, oversized, duplicate or unlisted inputs fail closed.

## Separate accounting, not a larger arbitrary output allowance

The fixed input allowance is exactly 147 reviewed paths. Its size derives from
the eager reads and explicit recipe dependency. Other `runtime/config` files are
rejected. Generated sources, runtime binaries, evidence aliases, diagnostics and
other outputs still share the original 128-file reserve. The derived whole-case
ceiling is therefore 147 + 128 = 275 files, with no unbounded input exemption.
All bytes, including fixed inputs, remain inside the existing 512 MiB observed
output ceiling. Input/source files remain capped at 2 MiB, DMB/RSC at 256 MiB each,
and captured streams/combined logs at 16 MiB. These checks are not OS quotas.

Both `staging-compile.json` and `staging-daemon.json` describe present and reserved
files before their respective launches. Counts distinguish required inputs,
generated source snapshots, runtime binaries, artifact aliases and diagnostics.
The complete anticipated diagnostic set must also fit the 128-file reserve.
The process helper rechecks the bounded inventory and actual input hashes before
creating either child. Output observations continue while it runs.

The final inventory counts files rather than directories, uses the derived bound,
and reports `inventory_complete` independently of `finalized`. `finalized` means
the finalization attempt ran; it does not imply a complete inventory or a pass.
Shared harvest callers do not opt into the flax input exemption. The process
helper's observed-exit and prelaunch output checks also apply to its existing
Linux callers; no harvest acceptance lane is selected or run by this correction.

## Historical daemon result, distinct from the file-count failure

Attempt 2's positive phase receipt records PID 3338, a 45-second configured limit,
`status=failed` and `RuntimeError('Task-owned output budget exceeded')`.
It confirms `direct_child_exited=true`, closed stdout/stderr writers and complete
stream capture, with zero observed bytes in both streams. The archived ZIP has no
positive `result.txt`, `runtime.log` or `fixture.json`.

The old phase receipt contains **no numeric return code**. The exact exit code is
unknown; neither a signal nor a clean exit can be inferred. Descendant/socket
cleanup is unverified. Its final manifest has `finalized=true` together with
`inventory_truncated=true`, so its inventory is incomplete. None of this is a
positive fixture pass. Payment, replay and persistence controls remain unrun.

Future phase receipts record the actually observed post-cleanup return code, or
`returncode=null` with `returncode_status=unknown` when unavailable. A failed phase
stays failed even when the observed child code is zero. Stream completion is
explicitly scoped to captured streams and remains separate from file inventory,
descendant cleanup and socket cleanup. Offline injected controls cover these cases.

Attempt-2 evidence remains in the immutable public artifact 13045688653 and private
review packet `libfile_22117c28461881919d4cf963f6baaa6b`. No old receipt was altered.
The GitHub-rejected CodeQL retry is not repeated or worked around here. Publication
and another native attempt require the parent's review of this source correction.
