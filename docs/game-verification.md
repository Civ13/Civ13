# Game verification evidence

Record the tested commit, BYOND version, map and dimensions, reproduction steps,
logs, actual captures, and acceptance limits together. Compilation, an isolated
fixture, client interaction, and production observations prove different things.
Keep those results separate.

## Choose the smallest meaningful check

- Read `.github/workflows/test.yml` and `scripts/travis_pre_byond.sh` for the
  current compiler version and build command. Capture full output and counts.
- Reuse existing isolated probes when present in the selected branch. The active
  season investigation introduced `scripts/test-season-memory.ps1`; the save
  investigation introduced `tests/world_save`. Inspect their current parameters,
  side effects, and cleanup before running. These paths are not guaranteed to
  exist in every checkout. Do not copy an unrelated branch's runtime changes to
  make a check available.
- Run fixture worlds with temporary storage and injected external-effect
  adapters. Do not run production launch/update scripts as test commands. A
  fixture pass does not prove that the full playable world behaves correctly.
- For gameplay changes, exercise the changed interaction in an authorized
  isolated game. Capture actual screenshots and reproducible steps. Use video
  when movement, timing, or a sequence cannot be assessed from stills. Record the
  tested commit, map/coordinates, input, expected behavior, and observed result.

Current captures are internal testing material; keep them local until sharing is
authorized. Use actual game assets and captures, not AI-generated art or mock
imagery. Inspect media for the claimed result. Missing captures or inaccessible
graphical tools remain explicit acceptance gaps.

## Season and memory investigations

Identify the actual supported map from source/configuration and record its
dimensions. Record the compiler and runtime versions separately if they differ,
process identity/start time, OS, memory metric and units, sampling cadence, and
the workload. Observe baseline, peak, and settled values over repeated complete
season cycles. Explain the settling rule and preserve transition-completion and
error logs. Compare equivalent workloads and baseline/control runs when useful.

Treat collection/reference counts, private bytes, resident memory, and working
set as distinct measurements. A sampled peak can miss a transient spike. A large
map or a short client session does not reproduce a long-running memory failure
by itself. Screenshots show visible state; they do not prove OOM remediation.
Report duration, sample gaps, retained-growth observations, runtime errors, and
unverified production conditions separately.

## Save import/export investigations

For area topology, level transitions, preflight boundaries and known fixture
gaps, use the [zone/persistence audit and regression matrix](zone-persistence-audit.md).
It distinguishes the recovered #3290 case from unverified follow-up risks.

Exercise the actual serializer with isolated adapters. Check nested objects,
datums and lists, supported aliases/cycles, metadata, object location fields,
edge turfs and multiple levels. Reject missing/duplicate/malformed turf grids
before clearing or mutating the world, and check that rejection preserves the
pre-import world. Use sanitized fixtures and temporary files. Compare the
round-trip invariants explicitly; existence of an output file is insufficient.

Test representative map scale separately from a small functional round trip.
Record fixture dimensions, object/turf counts, elapsed time, raw errors, and any
resource limit. Do not use or overwrite production saves for these checks.

## Assemble the existing evidence

The [manifest contract](game-evidence-format.md) describes a bundle directory
containing metadata and existing logs, captures, CSV samples, or fixture saves.
Keep generated bundles outside the repository. After authorized direct PR uploads,
verify attachment access before deleting local media; preserve reusable fixtures
and substantive verification notes in version control.
With a verified Python 3.9+ executable (on Windows, avoid Store aliases):

```powershell
& $PythonPath ./scripts/check-game-evidence.py "$EvidenceDirectory/manifest.json" --expected-commit '<full-tested-commit>' --report "$EvidenceDirectory/report.json"
```

Set `$PythonPath` to the verified interpreter and `$EvidenceDirectory` to an
absolute directory outside the checkout. Use a fresh report path. The checker never starts processes, connects to a
service, captures a screen, fetches a URL, or uploads files. It checks local file
hashes, references, commit equality, explicit skips, and sample structure. A
dirty test run needs its diff as a patch artifact. Obtain the expected commit
from the intended test target independently of the manifest.

`bundle_valid: true` means the evidence is structurally consistent. It is not a
gameplay or OOM verdict. Inspect the actual logs, captures, provenance, and all
failed/not-run criteria. URL availability remains unverified. Keep required
missing media visible in the PR and final result. Documentation/tooling-only
changes can use focused helper checks, explicitly recording gameplay as not
exercised.

Validate changes to the helper without running a game:

```powershell
& $PythonPath -m unittest discover -s tests -p test_game_evidence.py -v
```

These are synthetic fixtures only. The CI job runs the same helper tests; the
existing build job remains the game compilation gate. Report their scopes
separately. This guide does not authorize production restarts, live season
changes, save imports, deployment, or publication of captures.
