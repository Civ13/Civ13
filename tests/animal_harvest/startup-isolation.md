# Harvest startup diagnosis and local proposal

Last approved native attempt: [CI run 41271990812, attempt 1](https://github.com/Civ13/Civ13/actions/runs/41271990812),
head `8cc5ddd1d2e77bdede86fcb81d9994161c4f6704`.
[Build job 124746662359](https://github.com/Civ13/Civ13/actions/runs/41271990812/job/124746662359)
failed. Both compiler invocations used 516.1688 and reported zero errors and
warnings: normal game compile, then synthetic harvest fixture compile.
One daemon launched and returned after about 11 seconds of its 60-second bound.
Its numeric return code and native phase/result files were not uploaded by the
workflow, so they are not known from the retained CI artifacts.

The console records two startup runtimes:

| Error | Source | Stack |
| --- | --- | --- |
| `runtime error: bad index` | `code/_helpers/global_lists.dm:220`, `male_body_builds[B.name] = B` | `makeDatumRefLists()` -> `/datum/global_init/New()` -> world construction |
| `runtime error: Cannot read .garbage` | `code/processes/garbage.dm:152`, `if (processes.garbage)` | `qdel(/datum/global_init)` -> `/datum/global_init/New()` -> world construction |

The daemon opened loopback port 53923 before fixture `world/New()` closed
admission. This was not a zero-listener startup. The runner later reached its
post-runtime checks, read the no-port marker, printed the runtime log and raised
`RuntimeError('Harvest fixture failed')`. Its runtime-error check necessarily
rejects the recorded diagnostics; the unuploaded result or numeric return code
could also have contributed. No timeout was reported.

Four later tanning PASS markers show continued probe progress. Source order puts
the tall-grass and competing-action cases before tanning. This is not a clean
native pass: the final oven/rot/result outcome is unavailable. The host's
`functional_pass_cleanup_pending`, cleanup-acceptance branch and final success
printing were never reached. The earlier synthetic save/load cases precede the
tanning markers; they were part of this one daemon, not separate native phases.
No second daemon, extensive controls, production save data, Gaia or
production-server execution occurred. The 28-group/907-test Linux
offline baseline and evidence-checker job passed separately.

## Source diagnosis

The production DME includes `code/world.dm` before `global_lists.dm` and
`processes/__processes.dm`. `world.dm` constructs the global `init` datum, whose
`New()` immediately populates body/hair/species/HUD catalogs, loads configuration,
initializes chemistry and calls `qdel(src)`. The registry lists and process-list
instance are later global initializers. The first body datum has the valid
default name `Default`; the bad-index site is consistent with its destination
list not being ready. The `.garbage` diagnostic directly identifies a null
`processes` at that access. No native variable snapshot was retained for the
first error, so the exact body-list value is an inference, not an observed value.

[BYOND documents](https://www.byond.com/docs/guide/chap08.html) that global
initialization precedes `world/New()`. The old harvest adapter only replaced
`world/New()`; it left the earlier global constructor active. Its supposed
isolated startup therefore still entered production bootstrap. These production
source files and DME ordering are unchanged from the compared master. The busy
guards do not enter either failing path. No full-game or baseline native boot
comparison was authorized or run, so this does not prove Gaia has the errors or
that the problem exists exclusively in the fixture.

## Proposed fixture-only correction

Rename the generated copy of `/datum/global_init/New()` to
`/datum/global_init/proc/initialize_harvest_globals()` and invoke its **unchanged
body** once from the fixture's `world/New()`, after the first tick and before any
scenario. Assert that its global-list/process prerequisites exist before the
call, and that the normal male/female Default catalog entries exist afterward.
This keeps production configuration, catalog, chemistry and qdel behavior instead
of bypassing them or fabricating equivalent fixture state. Keep the existing
production-world startup replacement. Fail closed if either source marker or its
parent-call shape changes.

Production game files, GLOB construction, qdel, error capture and the runtime
guard are unchanged. No new generated checkout file, runtime input, output cap,
byte cap, timeout or native phase is introduced. The normal PR selection remains
two compiles (game 300 seconds, fixture 120 seconds) and one 60-second daemon in
the same 8x8x1 synthetic world with 147 fixed inputs, at most 153265 input bytes,
128 other evidence files, 275 evidence-tree files/512 MiB combined. The whole
declared fixture remains 279 files/1028 MiB of observational accounting. Existing
descendant/socket/CPU/RSS limitations remain; the proposal does not prevent the
observed initial listener.

Offline checks exercise source-body preservation, marker-drift refusal,
post-global/pre-scenario call ordering and the unchanged runtime guards, in the
registered `harvest_inputs` group. Retention controls continue to inject both
process phases. This proposal has not been compiled, published or executed
natively; it requires source review before a separately authorized retry.
