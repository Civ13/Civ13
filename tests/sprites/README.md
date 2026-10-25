# Compiled sprite checks

See [the audit and provenance](../../docs/sprite-audit.md). `run.py` compiles production type defaults with normal startup disabled and runs `validate.py` over `required-types.json`. Required types must have real, nonempty DMI frames. The actual wrong-resource negative control runs from generated source and detects inherited resource mistakes even when the project compiles.

`report.py` builds a source-linked unresolved-default review queue. `create_cinchona.py` and `create_crafted_repairs.py` reproduce the conventional pixel assets using Pillow; they are authoring utilities, not CI mutations.

No live server, player data, game instances or external-effect tests are involved. Constructors and overlay/worn/held rendering are outside this defaults inventory. Add meaningful dedicated checks for those behaviors when introducing dynamic graphics.

## Current Linux toolchain and historical fixtures

Current extraction requires `--byond-bin <absolute-bin>` and
`--byond-archive <pinned-linux-zip>`. `scripts/byond_runtime.py` reads the central
manifest, verifies the complete archive size/hash, and compares DreamMaker,
DreamDaemon, libbyond.so and libext.so with their exact regular ZIP members.
Missing, changed, duplicate or linked members fail before execution. Verification
is repeated immediately before daemon launch and after extraction. This is passive
bundled-file identity, not proof of the system loader, all dynamic dependencies,
external extensions, or an atomic lock against concurrent file replacement.

Compilation must succeed with exactly one target-version banner across both
output streams and zero errors/warnings. Evidence records that observed compiler
version, archive/member identity, unchanged before/after Git head/tree/dirty-patch
identity, generated-source hashes, diagnostics, inventory and exported PNG/mapping
hashes. The atlas embeds the sprite receipt in its source-linked JSON/HTML.
The daemon version is identified by matching archive bytes, not an invented
runtime-banner observation. The controller sets its bundled library and BYOND
system paths explicitly; it refuses injected preload/audit settings.

Use a fresh output destination for each attempt. Existing output/evidence/logs
and generated files (including dangling links) are preserved and rejected.
Failed admitted attempts retain a failed receipt and available compiler/daemon
diagnostics, including timeout output; generated fixture files remain cleaned.
The 180-second compile and 60-second daemon limits and trusted isolated fixture
behavior are unchanged. No new ordinary-PR native admission is introduced.

Previously admitted Windows/516.1681 fixtures must explicitly select
`--legacy-fixture-5161681` (also accepted by the atlas generator). That mode cannot
claim a current archive identity; its evidence is labeled historical/unverified
members. It is not a workaround for failing current-version checks. Existing
historical receipts are unchanged. Current Windows sprite acceptance is not added.

## Proposed artifact-only Pages acceptance

Do not merge the Pages migration merely to make its native check available:
master pushes retain their existing publication behavior. The proposal extends
the already-registered `api-pages.yml` manual dispatch with `artifact_only=true`
and `expected_head=<reviewed 40-hex commit>`. The intended ref is the independently
reviewed feature branch. No dispatch is authorized by these source instructions.

After main reviews and authorizes publication of that exact branch and one bounded
acceptance attempt, verify the branch head and dispatch the existing workflow with
both inputs. Its admission rejects unknown modes, missing/mismatched SHA, tag refs,
and false/default publication mode on non-master. The acceptance path has only
contents-read permission, no Pages configuration or Pages artifact upload, and no
deployment. The deploy job independently requires master and non-artifact mode.
The positive atlas generation/check and named wrong-resource control must pass;
review acquisition, exact compiler output, all member identities, source/output
receipts and retained artifacts before a deployment-triggering merge. A green
offline/ordinary-PR build does not substitute for that native extraction evidence.

GitHub documents dispatch by ref and inputs; its CLI reads the chosen ref's
workflow definition for input collection. This supports the proposed branch route
but does not prove this repository's service accepts inputs absent from the old
default-branch definition. If it rejects admission, stop and report that blocker;
never retry on master/default, omit the artifact flag, or merge a controller to
get around it. No activation attempt or native workload has run for this proposal.
See [GitHub manual-run guidance](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
and [the CLI implementation](https://github.com/cli/cli/blob/trunk/pkg/cmd/workflow/run/run.go).
