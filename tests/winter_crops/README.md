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

**Remaining limits:** crop snapshots use `vstatic` and do not prove ordinary crop
callback restoration or ownership. No natural 600-tick growth/decay wait was
observed; the unchanged daemon cap is 45 seconds. Direct methods and diagnostic
RNG samples do not prove natural cadence, exact long-run yields or complete winter
survival. Oral chemistry is not connected-client eating. No rendered gameplay,
map-spawn reachability, multiplayer interaction or full-world save/load acceptance
is claimed. The older native fixture evidence is not relabeled for this source.
