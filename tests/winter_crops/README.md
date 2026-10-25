# Winter crop source checks

Run `python -m unittest discover -s tests/winter_crops -p 'test_*.py' -v` from the repository root. The tests use only the Python standard library; CI runs with `-I -S` to exclude site packages. PNG CRCs, RGBA filters, DMI metadata, nonempty alpha and independently recorded per-state/whole-file SHA-256 hashes are checked. Pillow is required only for the explicitly invoked `assets.py` repack/preview tooling.

The suite executes a deliberately narrow, fail-closed Python translation of the production water procedure and outdoor-plot admission helper against synthetic engine boundaries. It checks opt-in snowstorm survival, unchanged ordinary-crop freezing, water consumption, drought, sandstorms, rain, irrigation and existing mushroom exemptions. In-memory omission/inversion controls prove that the hardiness assertions distinguish the old and wrong-branch behaviors. Unknown statements fail translation instead of being silently ignored.

Plump-helmet checks resolve its explicit production mushroom ancestry, preserving indoor growth and water exemptions. The half-rate override and inherited stage-growth procedure are projected with injected probability outcomes, including progression through ripe stages to eventual overmaturity. The illustrated sequence is not a guaranteed maturation deadline: stochastic failures can delay growth.

Additional source contracts cover seed biome/season admission, existing foraging registration, seed debit and return, finite crop lifecycle, soil consumption, nutrition and shelf life. Real DMI metadata and pixels are inspected for all turnip and plump-helmet states; these are asset checks, not screenshots from gameplay.

Not established: native compilation, native save/load, connected-client planting or harvesting, map-spawn reachability, rendered gameplay, or elapsed winter food balance. Production weather uses a seasonal crop-hardiness abstraction, not a Celsius plant-survival model. Native and player acceptance require separate authorization and exact-source evidence.

The ordinary evidence-checker runs this offline suite only under its existing extensive/introduced-suite guard. No native eligibility or default broad discovery is added.
