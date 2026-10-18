# Accessory removal actor

The production change uses the passed `user` for hand placement, matching its
guard and fingerprint attribution. The no-user fallback still moves the item to
its current turf. This independently adapts the lead found in SepuIka's RuCiv13
commit `97b393727e85250935d3b4d577dccd3894bc1c99` (2024-06-11), rather than
cherry-picking its guard-only change. The fork leaves custody and fingerprints
using different actors.

Callers reviewed: clothing `remove_accessory`, the removal verb, stripping's
accessory path, armor damage, and accessory destruction's no-argument call.
Holster and sheath removal clear their suit verbs before forwarding the actor
through their parent. No caller, capacity, payload, recipe or balance changes.

Offline preparation and oracle controls:

```powershell
py -3 -B -m unittest discover -s tests/accessory_removal -v
py -3 -B tests/accessory_removal/run.py --prepare-only --evidence-dir <fresh-path>
```

The existing automatic CI selector selects this new executable suite on PRs.
Its one guarded workflow step runs the positive probe and two native controls.
With a separately authorized native slot, run the same CLI with
`--byond-bin <516.1681-bin>` and fresh evidence, then repeat with
`--negative-control original-usr` and `--negative-control fork-guard`.
Preparation alone never invokes a compiler, daemon, client or listener.

The full production DME is compiled without maps, using the existing
`isolated_startup` world/global constructor adapter. The normal removal handlers,
holster/sheath overrides, actual overlays, real human hand placement and fallback,
and native item containment are retained. Human startup and hand-icon updates
are presentation/setup seams; fingerprint calls record their actor arguments
instead of generating DNA/account prints. The clothing icon callback counts
refreshes. Initial attachment, hands-full state and payload placement are fixture
setup. No strip UI or connected-client acceptance is claimed.

There are 27 explicit cases (nine actor/hand states across tie, holster and sheath)
and 270 per-label checks. Each verifies completion, parent/overlay cleanup,
correct hands or turf, fingerprint actor, caller membership, payload identity,
subtype verbs, single-item custody and caller refresh. The native result records
all labels and the exact commit. The original-source control must fail the named
different-`usr` custody oracle; the fork guard control must fail the named
null-user/non-null-`usr` turf oracle. Generic errors, wrong counts, unrelated
failures or missing terminal output do not count as successful controls.

Generated inputs, source hashes, compiler/native logs and result JSON are retained
in the selected evidence directory. Owned temporary root compiler files are
removed in `finally`; existing files and evidence are never overwritten. Native
execution is pending until automatic CI runs; local work is source/offline only.
