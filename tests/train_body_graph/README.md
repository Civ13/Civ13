# Train body graph capture boundary

`python3 -m unittest discover -s tests/train_body_graph -v` checks source guards only.
No native capture or restore execution has been verified.
Local exact-capture quarantine restoration is now implemented but unproven. This is **not** a
lossless transport codec, and must not enable departure or source deletion.

The capture adapter uses the real production `BuildVarDirectory` and its
`before_save_context`/`get_saved_vars` hooks, not an empty projection. It writes
an in-memory v3 savefile then explicit JSON tags for native values, entries and
cyclic list references. Native resources, external world references, unsaved
inventory, budget overruns and tick-crossing are rejected rather than omitted.
Production hooks may update corpse age and align runtime sub-tile state; this
is not a side-effect-free snapshot. Call only under an authorized frozen source
transaction, and retain the source when capture fails.

## Remaining mandatory integration work

* Establish admitted **exact** body/item/datums and fields using representative
  production human, NPC, corpse, wound, severed limb, nested inventory and
  reagent fixtures. Family admission here is for capture, never constructor
  authorization. Supported equipment does not imply every variant captures.
* Identify native resources and external/shared datum references in those
  real bodies; reject unsupported bodies or add reviewed portable projections.
* Split the production `Load_Entry` unowned-human rejuvenation policy from body
  transfer. The default-TRUE `rejuvenate_unowned_human_on_load` hook is now overridden FALSE in this adapter; ordinary world-save behavior is unchanged.
* Validate every field and typed path, reference range and reachability,
  containment ownership and cycles **before** any restore constructor runs.
  There is deliberately no remote restore entrypoint. `restore_local_capture` accepts only this same instance’s exact unconsumed capture and cannot import a remote packet.
* Reuse guarded production `Load_Entry` only inside an isolated destination
  quarantine; audit all constructors, `after_load`, `persistence_import_fields`,
  `persistence_restore_finished`, corpse registry and reagent ownership hooks.
* Keep account registration/client attachment outside decoding and behind
  authoritative transaction ownership. Retain journaled source custody until
  destination quarantine and player-home claim commit are durable.
* Prove round-trip injuries, organs, DNA, reagent volume, aliases, inventory,
  death state and age; test crash/retry/rollback without duplication or healing.

This adapter does not claim those acceptance tests passed. No live server,
client, character record, or world save is modified by the source tests.

## Full-source native fixture (execution pending)

`python3 tests/train_body_graph/run.py --prepare-only --evidence-dir <fresh>`
prepares the real production code with isolated startup and no map includes.
The adapter is included explicitly in the fixture, not the production DME.
`--byond-bin <516.1688 bin> --compile-only` compiles without launching a daemon.
Native execution additionally requires `--allow-native-execution` and parent
authorization; do not infer authorization from fixture availability.

The 30-check probe constructs real production owned/injured humans with organs,
wounds and carried inventory, a sheep and a dead human. It asserts successful
capture, encoded injury/inventory/death values, bounded entry/list reference
closure, missing-field/dangling-ref refusal, external turf refusal and source
retention. Capture failures are retained in `result.json.capture_errors` and
fail the suite. These are acceptance assertions, **not passed results**.
The fixture-only wire inspector performs no constructors from input. Four additional checks exercise local quarantine roundtrip, injury preservation, one-shot consumption and dead-state preservation. These remain unrun.

## Local quarantine boundary

The local restore preflight validates encoded types and references, unique rooted
movable containment and graph reachability before calling production Load_Entry.
Admission is the exact locally pinned capture, not a static remote schema. The
receipt is consumed before construction; mismatch, replay and foreign adapter
inputs are rejected. A detached non-saving holder contains the returned body.
No client attachment, account registration, after_load, restore_finished or
source deletion occurs. Failed construction queues only adapter-created objects
for deletion. Constructor side effects and asynchronous deletion are NOT yet
proven fully reversible; this is not a crash-safe remote transfer primitive.

Native run 0f7e6f reached all 19 prior assertions with no runtime errors but
failed 11: human teeth and sheep transform were explicitly unsupported. Narrow
follow-up admits exact human teeth using production full-state export and exact
native /matrix using six numeric finite coefficients bounded to +/-1,000,000.
Matrix preflight requires exactly type+a..f. The new 22-check fixture adds
teeth-count and six-component transform roundtrip plus numeric bound controls.
These new native assertions are pending; prior failures are not superseded by
source test passes.

Next narrow follow-up after a509263 (9/22, runtime_error=0): canonical Human
species is referenced locally by exact all_species identity after comparison
against its audited data-only constructor baseline (registry race index checked
separately). Noncanonical or modified definitions reject. No HUD or arbitrary
species graph is cloned. Exact empty atom.filters uses an explicit marker and
reconstructs an empty list; custom/nonempty filters reject. Six new native checks
cover canonical/noncanonical/mutated definitions, registry identity and empty/
custom filters. Remote registry/version compatibility remains unsupported.

Source audit following dbe531 (17/28, no runtime errors): production
`species.create_organs` adds `has_limbs[tag].descriptor = O.name`. The registry
comparison now admits only that derived field when it exactly equals the
compiled default limb name; limb paths, keys, membership and extra fields still
reject. Rejections include field paths (never character values). Two further
checks cover canonical metadata after actual human construction and refusal of
a changed descriptor. The native rerun remains pending.
