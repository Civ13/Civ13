# Native random flower state audit

The exact source at `10d264e5896221b34949ee4b67c0fd2b94bde249` requests
`flower1..14` from `icons/obj/flora/ausflora.dmi`, whose decoded metadata/pixels
provide `flower1`, `flower2`, and `flower4..14`. `baseline-10d264e.json` preserves
the exhaustive failing report, source/icon hashes and Git blob identities. The
checker exited 1 for missing `flower3` before any source correction. Its recorded
source text matches the exact Git object after ordinary Windows line-ending
normalization; the raw Git-object SHA-256 is recorded separately.

The correction maps only the existing draw's third outcome to existing human-made
`flower2`. It preserves the original `rand(1,14)` call, its position and the other
13 outcomes. Slot 2 and slot 3 now share one existing appearance. This does not
claim to reconstruct the intended missing drawing. No DMI, placement probability,
harvest behavior or new external/generated art changes.

From the repository root, with a verified Python 3 interpreter and Pillow:

```powershell
& $PythonPath tools/flower_state_audit/audit.py
& $PythonPath -m unittest discover -s tools/flower_state_audit -p test_audit.py -v
```

`--source PATH --icon PATH --output PATH` permits auditing an exported historical
source and the exact icon. Preserve the baseline report; write new output elsewhere.
The checker exhaustively enumerates the bounded production constructor, rejects
unrecognized constructor edits, and decodes actual PNG/DMI pixels. Tests remove
the correction to recover the original missing-state failure and reject a missing
replacement. These are offline projections, not native construction or gameplay.

This fix is separate from #3332 and the inactive decorative herb types. It changes
future construction only; it does not migrate previously saved `flower3` instances.
No runtime/server, deployment or map activation is authorized or performed.

In the local combined review, the checker also recognizes the exact fixed-scenery
guard and audits its ordinary-flower else branch. The alias-removal and missing
replacement controls accept the additional indentation; the original failed
baseline report remains byte-for-byte unchanged.
