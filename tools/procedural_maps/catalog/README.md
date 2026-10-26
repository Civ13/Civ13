# Source-backed resource proposal

`native-resources-v0.1.json` is frozen by the adjacent SHA-256 file. It records
exact source pins, anchors, observed outputs and unresolved gates. Its status
is **not admitted**: no native interaction or automatic FOOD/WOOD/STONE mapping
is implemented. Tests preserve its identity and source facts. A revision needs
a new proposal ID and review, not a silent edit of this frozen file.

The static DMM type/var/area catalog lives in `dmm_export.py` and uses the
repository's own source at the pinned commit. No copied DM source, third-party
library or native binary is distributed here. Source drift rejects export;
see the [guide](../../../docs/procedural-maps.md) for a matching catalog checkout.
