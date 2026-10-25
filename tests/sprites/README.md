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

## Artifact-only Pages acceptance

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
workflow definition for input collection. The acceptance below also demonstrated
that this repository's workflow UI loaded and accepted the feature branch's inputs
while they were absent from the default-branch definition. If a future attempt
rejects admission, stop and report that blocker;
never retry on master/default, omit the artifact flag, or merge a controller to
get around it.
See [GitHub manual-run guidance](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
and [the CLI implementation](https://github.com/cli/cli/blob/trunk/pkg/cmd/workflow/run/run.go).

### Reviewed 516.1688 acceptance receipt

The separately authorized [run 40228475523](https://github.com/Civ13/Civ13/actions/runs/40228475523)
passed on 2026-10-25 at exact tested head
`c60f77f2c4a89e7b25920aff92fa366eaa191e58` (source tree
`759196b1f858a800e8f904f6fe8d759ee1e4d423`). This receipt does not claim execution
of later documentation commits or authorize another native attempt.

- The admitted inputs were `artifact_only=true` and `expected_head` equal to that
  tested head. The build token had contents-read permission; Configure Pages,
  Pages artifact upload and the deploy job were all skipped.
- Both actual fixture compilations reported 516.1688 and zero errors/warnings.
  Positive extraction passed all 52 required inherited-default/DMI/pixel checks
  with 10,538 inventoried types. The named wrong-resource control detected the
  injected inherited-icon mistake with 8,780 inventoried types.
- Both receipts recorded unchanged, clean tracked source at that head/tree.
  Acquisition and DreamMaker/DreamDaemon/libbyond.so/libext.so identities matched
  the pinned Linux archive SHA256
  `16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9`.
  Receipt-bound compiler/runtime logs and inventories were independently hashed;
  all 1,763 exported PNGs plus `exports.json` matched their receipt hashes.
  Crafting JSON embedded the identical sprite receipt; API and crafting outputs
  identified the exact tested source head.
- Retained acceptance artifact **12612526852** has ZIP SHA256
  `955bec1d2100987849a94fc30d6ebf09dc35e14edabf064ef5c92f9d0cf5c2e5`;
  evidence artifact **12612720948** has ZIP SHA256
  `eac7b9ab41938bfdf2269c24ff062c0d93ba1ac64fbfd166a6fc778f4767b903`.
  Both are attached to the linked run and subject to artifact retention.

Limits: the inventories still contained 580 positive / 411 negative unresolved
defaults outside the required assertions. Each daemon briefly opened an ephemeral
runner listener before closing new-user admission; this is not a no-listen proof.
Bundled-member identity is not full dynamic-dependency verification, and neither
gameplay nor browser visual acceptance was established. Cleanup returned through
the runner's `finally` unlink path, and the second run's generated-file preflight
confirmed the first run's files were absent; no separate post-negative filesystem
listing was retained. These limits are not waived by a green workflow.
