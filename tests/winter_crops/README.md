# Winter crop source checks

Run `python -m unittest discover -s tests/winter_crops -p 'test_*.py' -v` from the repository root. The tests use only the Python standard library; CI runs with `-I -S` to exclude site packages. PNG CRCs, RGBA filters, DMI metadata, nonempty alpha and independently recorded per-state/whole-file SHA-256 hashes are checked. Pillow is required only for the explicitly invoked `assets.py` repack/preview tooling.

The suite executes a deliberately narrow, fail-closed Python translation of the production water procedure and outdoor-plot admission helper against synthetic engine boundaries. It checks opt-in snowstorm survival, unchanged ordinary-crop freezing, water consumption, drought, sandstorms, rain, irrigation and existing mushroom exemptions. In-memory omission/inversion controls prove that the hardiness assertions distinguish the old and wrong-branch behaviors. Unknown statements fail translation instead of being silently ignored.

Plump-helmet checks resolve its explicit production mushroom ancestry, preserving indoor growth and water exemptions. The half-rate override and inherited stage-growth procedure are projected with injected probability outcomes, including progression through ripe stages to eventual overmaturity. The illustrated sequence is not a guaranteed maturation deadline: stochastic failures can delay growth.

Additional source contracts cover seed biome/season admission, existing foraging registration, seed debit and return, finite crop lifecycle, soil consumption, nutrition and shelf life. Real DMI metadata and pixels are inspected for all turnip and plump-helmet states; these are asset checks, not screenshots from gameplay.

This offline suite alone does not establish native compilation or save/load, connected-client planting or harvesting, map-spawn reachability, rendered gameplay, or elapsed winter food balance. Production weather uses a seasonal crop-hardiness abstraction, not a Celsius plant-survival model. The separate native evidence below covers only its stated exact-source scope.

The ordinary evidence-checker runs this offline suite only under its existing extensive/introduced-suite guard. No native eligibility or default broad discovery is added.

## Exact-source native acceptance

An authorized Linux BYOND 516.1688 one-shot passed for production commit
[`8070d5cbe26c39c42d6bf5ce132d16f7cc3768e0`](https://github.com/Civ13/Civ13/commit/8070d5cbe26c39c42d6bf5ce132d16f7cc3768e0),
tree `c26a26bf55518defa4f63f19f00695882183aae7`. This evidence does not automatically
cover later source changes.

- Controller: [`2e3d905c67381886c0a67518e0242b2fbe6f2511`](https://github.com/Civ13/Civ13/commit/2e3d905c67381886c0a67518e0242b2fbe6f2511).
- [Hosted run 40210557013, attempt 1](https://github.com/Civ13/Civ13/actions/runs/40210557013).
- Retained artifact ID `12605641565`, name `winter-1688-8070d5-attempt1-40210557013`.
  ZIP SHA256: `6e10ce9885dbc960836610612c5507fce39f0f44ecde1b454e23d1465ec5e484`.
  Hosted artifacts have seven-day retention; identity alone is not permanent availability.
- Five compilations completed with zero errors/warnings. Seven daemon phases
  passed: baseline direct-path roundtrip (239 assertions), writer (20), fresh
  reader (21), and four exact causal-control rejections.
- Controls removed snowstorm hardiness, the immature open-sky recheck, mushroom
  ancestry, or planting payment. Each failed at its intended assertion, not an
  unrelated error. No retry was used.
- All 209 retained files were hash-verified. Independent replay checked ordered
  oracles, exact source/controller bindings, runtime-member receipts, restart
  transfer hashes, zero owned listeners at readiness and cleanup for all 12 phases.
  The unchanged owned-process/resource guards remained in force.
- Hosted source checks also passed: 128 controller tests, 12 winter source tests,
  and unchanged exact-source Atlas freshness.

The synthetic fixture calls actual production sowing, harvest, weather, soil and
stage methods; checks both crops' sprite states and all eight starter-seed pools;
and exercises oral reagent transfer/metabolism. Writer/fresh-reader phases retain
partial food nutrition, accumulated food age, seed stock and frozen crop scalars.

**Limits of this historical run:** crop snapshots use `vstatic` and do not prove ordinary crop
callback restoration or ownership. No natural 600-tick growth/decay wait was
observed; the unchanged daemon cap is 45 seconds. Direct methods and diagnostic
RNG samples do not prove natural cadence, exact long-run yields or complete winter
survival. Oral chemistry is not connected-client eating. No rendered gameplay,
map-spawn reachability, multiplayer interaction or full-world save/load acceptance
is claimed. The older native fixture evidence is not relabeled for this source.

## Natural writer/reload at ae99e2b

A separately approved Linux BYOND 516.1688 one-shot passed for exact production
head [`ae99e2b07c3ba9a2dd191ba07b6dba27a4bfda3e`](https://github.com/Civ13/Civ13/commit/ae99e2b07c3ba9a2dd191ba07b6dba27a4bfda3e),
tree `3fedd061d42235af0d7699d9eb39135d41c25fd5`:

- Controller [`d83bf04f914aaa1da445fcec85496515280adaa9`](https://github.com/Civ13/Civ13/commit/d83bf04f914aaa1da445fcec85496515280adaa9);
  [run 40260631990, attempt 1](https://github.com/Civ13/Civ13/actions/runs/40260631990).
- Artifact `12624672460`, name `winter-growth-1688-ae99e2b-attempt3-40260631990`,
  ZIP SHA256 `fc38ca924cc038fd3445550bc6d9f7234254a22e7d84f4b5385f9bca8e74bb6b`.
  Hosted retention is seven days, not permanent availability.
- One clean compilation and two sequential native phases took 9.04, 136.23 and
  136.08 seconds. Each phase had a 180-second cap and the aggregate cap was 600
  seconds, with unchanged CPU/memory/ownership limits. The older 45-second packet
  was not modified or reinterpreted.
- Writer and fresh reader each observed 80 soil payments: 8 turnip, 8 potato,
  32 plump helmet and 32 ordinary mushroom, spanning two natural crop intervals.
  Each observed four ordinary food-aging events. Stochastic plump advances were
  15 before save and 20 after reload, without forced RNG.
- Ordinary constructors and actual Save_World/Load_World callbacks conserved
  tracked crop/soil/seed state and partially eaten food. The reader supplied 21
  observations and passed the cadence oracle without observed duplicate callback
  streams. It starts a new full wait, not the remaining pre-save wait; existing
  potato/mushroom controls share this inherited scheduling behavior.
- Independent replay verified all 97 retained hashes, exact source/controller and
  runtime bindings, restart transfer receipts, all three owned cleanups and both
  empty listener censuses. Actual retained round.json/map.txt/completion markers
  passed strict header checks in both phases. Production whole-generation
  validation passed; binary level saves are not retained for independent replay.
- Hosted preparation passed 106 controller checks, exact-checkout admission,
  12 winter source tests and 3,023-record Atlas freshness.

Earlier failed attempts remain part of the record: [40258600706](https://github.com/Civ13/Civ13/actions/runs/40258600706)
stopped before compiler/game launch on a stale source-file count. The separately
approved replacement [40259242360](https://github.com/Civ13/Civ13/actions/runs/40259242360)
passed compilation and natural writer checks but failed reader generation preflight
with `Invalid saved round identity` before Load_World. Its isolated startup had
omitted ordinary generate_gameid. The successful correction invokes that ordinary
initializer and leaves production validation unchanged. Earlier raw headers were
not retained and were not reconstructed; each replacement required fresh approval.

This establishes focused ordinary growth/decay and continued callbacks after a
fresh-process reload, not a complete harvest, full player bootstrap/forage journey,
remaining-wait restoration, full-round identity/mode restoration through
ticker.loadmap, connected-client behavior, or full-world/server acceptance.

## Final seed-admission change and merge

The later [`379875cabaec0be86ac86f8e9de36a9cb0d7815f`](https://github.com/Civ13/Civ13/commit/379875cabaec0be86ac86f8e9de36a9cb0d7815f)
changes only plump-spore planting admission, its tests and documentation; it does
not change crop growth, food decay or save/load code. Exact-head
[ordinary CI 40262318395](https://github.com/Civ13/Civ13/actions/runs/40262318395)
compiled with zero errors/warnings and passed all 17 winter tests, including the
1,323-case admission matrix. All eight exact-head workflows passed. Optional
native/tree/Atlas lanes were skipped by ordinary selection policy; separate local
source checks passed 25 tree tests and unchanged Atlas freshness. No native rerun
of this admission change is claimed.

PR #3314 was squash-merged as `a1f08b3d3ac366cd85a08eaf2fd4f9e734faa9a6`;
[post-merge ordinary CI 40262819601](https://github.com/Civ13/Civ13/actions/runs/40262819601)
passed. Native results remain bound to their original tested heads, not the squash
merge or later documentation updates.

## Plump-spore admission boundaries

`test_plump_admission.py` projects the new seed-only admission override and compares
all six Nomads IDs plus a non-Nomads control, indoor/outdoor/other locations, all
inherited mushroom biomes plus desert/semiarid/unknown, and supported/unsupported
seasons. Source parity pins inherited biome/season lists and tropical/map bypasses.
The unchanged floor early-return contract is checked before skill, constructor and
seed debit; omission and premature-spawn controls must fail. Its resource sentinel
is a source-order model, not a native player interaction test. Existing growth and
forage behavior are unchanged. Native evidence for ae99e2b remains bound to that
head and does not automatically cover this later admission correction.
