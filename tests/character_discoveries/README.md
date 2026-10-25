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
