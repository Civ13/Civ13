# Game CI and opt-in runtime regressions

Automatic CI keeps a lightweight change detector and the stable build check.
Documentation-only changes skip game compilation. Source, DM includes anywhere,
maps, assets, config, harnesses, shared CI and unknown paths select compilation.
Missing comparisons and manual runs also select compilation. The detector fails
closed; failed or missing detector output fails build instead of silently skipping.

Extensive runtime suites are opt-in only. In Actions, select CI, Run workflow,
and enable extensive_regressions to run recipes, world-save, chemistry (including
negative controls), power, boats and batteries. The option defaults to false.
Push and PR events cannot enable runtime suites, even with a truthy input.

Train collision regression has only workflow_dispatch: selecting Run workflow is
the explicit opt-in. It compiles and runs the existing bounded isolated probes.
It is no longer an automatic PR check. Current branch protection has no required
train check; adding one would conflict with this manual-only policy.

Offline evidence, documentation generation, tooling contracts and security
analysis remain automatic. The selector runs eight regressions and actionlint
on every workflow. Tests include actual Git documentation and deleted-include
diffs, shared paths, failed comparisons and manual opt-in positive/negative cases.

Run with a verified interpreter:
python -m unittest discover -s tests -p test_ci_selection.py -v
Publication remains master-only. A skipped runtime suite is not gameplay evidence.
