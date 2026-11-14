# Imported Python tool fixes, 2026-11-14

Reviewed seven medium archive patches against master
1eca8c98805adf352ccc7c1139b789cd846bcf88. All seven accepted; none rejected or deferred.

| Patch | Fix |
|---|---|
| m76 | Cold-plan distance accepts signed integer offsets and zero, still rejects booleans/non-integers. |
| m77 | UpdatePaths omits an absent requested old map-edited property instead of crashing. |
| m78 | Recipe-memory eviction excludes the recipe just recorded. |
| m79 | Mapmerge reads the .before backup its frontend actually creates. |
| m80 | Unused-map-key deletion materializes the dictionary key view before removing entries. |
| m81 | Radio frequency range validation rejects nonfinite numbers before integer conversion. |
| m82 | Strike-coordinate validation likewise rejects nonfinite values as RadioError. |

Eight tests import and execute production Python implementations using synthetic
observations and temporary maps. No game, model or relay connection is used by
the new regression suite. Every test fails/errors with all seven patches reversed;
all pass after restoration (generated Python bytecode caches cleared to avoid
same-second/equal-size source restoration cache artifacts).

Commands:
- python3 -B tests/imported_python_tools/test_regressions.py: 8 passed.
- python3 -B scripts/ci_baseline.py unit --suite imported_python_tools --output /tmp/medium-tools-receipt.json: 8 passed.
- python3 -m unittest discover -s tests/transfer_storage -p 'test_radio*.py': 21 passed.
- git diff --check: clean.

The focused tests exercise actual Python, not Python copies of DM. They establish
the selected functions and temporary map workflow, not deployed agent or relay
acceptance. Full preflight was intentionally not rerun under shared disk
constraints; the earlier item-transfer preflight is not evidence for this head.
No DM code changes, deployment, live-server operation or merge.
