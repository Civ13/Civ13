# Character-discovery source checks

Run `python -B tests/character_discoveries/test_discoveries.py -v` from the root.
These tests launch no BYOND process. Learning/rendering use fail-closed source
projections; serializer and lifecycle checks are static integration contracts.
They do not establish native JSON parity, save/load, reconnect or client UI.
See `docs/character-discoveries.md` for the source audit and acceptance matrix.

The evidence-checker CI step is guarded by the existing explicit extensive or
introduced-suite admission. It runs only this directory under Python isolated
mode (`-I -B`); no broad test discovery or native launch is added. Tests use only
Python standard-library imports and read the current repository source. They do
not require Git history, external packages, network access or a BYOND install.

## Separate native evidence

The isolated one-shot [run 40215733119](https://github.com/Civ13/Civ13/actions/runs/40215733119)
passed for feature head `9c54e1b57097035d51c35e4ea9cb755e7aa12a92`, with controller
`f13308820a5a9d95a564b2f49575ef9a20fbc61b`. Baseline native assertions numbered
43 roundtrip / 4 writer / 11 fresh reader; four causal controls rejected their
exact intended assertions. All twelve compiler/daemon phases had verified
owned-process cleanup. Offline evidence replay verified 226 retained files.

This is separate from the Python source tests above. Native checks use actual
production smell/mind/generic serializer paths with headless output sinks and
inert humans. They do not prove connected-client Notes rendering, full-body
save/reclaim, live reconnect or real lobby respawn. See the feature document for
exact scope, source identities and remaining acceptance.
