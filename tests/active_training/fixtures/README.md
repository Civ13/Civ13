# Historical regression controls

These text fixtures preserve actual predecessor source so the offline regression
controls do not depend on PR-only commits surviving a squash merge. They are
read as text and are never compiled or executed. Keep the faulty lines intact.

- `round_identity_omission.dm.txt` is the complete `/world/New()` procedure from
  `tests/active_training/game.dm` at
  `250ff2ca00c85302f57c8e1a67764fdb536b5596`. It omits `generate_gameid()` before
  native world saving. The test also rejects synthetic IDs and late initialization.
- `scalar_python_arguments.ps1.txt` contains the original assignment and both
  Python invocation lines, in source order, from `tests/active_training/run.ps1`
  at `09eb8a1378cda690af682cac9d1034c643f2ff1e`. Without `[string[]]`, the Linux
  single-element branch unwraps to a string; both splat sites remain represented.

The commit IDs above document provenance only; tests read these checked-in
files instead of looking up either commit. The separate production
original-silence control remains pinned to
`cc03b199128f8afed58713912c551ad7556e6bc4` and retains its source-hash oracle.
