# Source-backed resource proposal

`native-resources-v0.1.json` is frozen by the adjacent SHA-256 file. It records
exact source pins, anchors, observed outputs and unresolved gates. Its status
is **not admitted**: no native interaction or automatic FOOD/WOOD/STONE mapping
is implemented. Tests preserve its identity and source facts. A revision needs
a new proposal ID and review, not a silent edit of this frozen file.

This one frozen JSON file retains its original CRLF bytes with a specific
`-text` Git attribute. Do not normalize it on checkout or staging: the adjacent
checksum binds the exact bytes, independently of the host operating system.

The static DMM type/var/area catalogs live in `dmm_export.py`: version 1 retains
the original source, version 2 pins the reviewed current source. Sidecars and
new manifests bind the selected catalog; the historical resource proposal stays
unchanged and its original source evidence is tested with a matching checkout.
No copied DM source, third-party library or native binary is distributed here. Source drift rejects export;
see the [guide](../../../docs/procedural-maps.md) for a matching catalog checkout.
