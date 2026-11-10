# Atlas entity coverage

The current Crafting Atlas indexes recipe inputs and outputs, not the complete
compiled entity hierarchy. A recipe count is not an encyclopedia coverage
percentage or proof of gameplay reachability.

Run `python scripts/atlas/coverage.py` to report resource families, acquisition
annotations and entries with neither an output-producing recipe nor a documented
acquisition route. Review those entries against source, map/job availability,
inheritance and procedural production before claiming they are unobtainable.
Abstract input categories are reported separately from concrete resource gaps.

The fork and spoon requirements use `category:hard_material`. This is a
polymorphic input, not a spawnable material named after its receiver procedure.
The catalog preserves the recipe's existing conditional/context-dependent label;
its source still controls material hardness, resource thresholds and map gates.
Unknown procedure-owned native stack recipes fail generation until their input
meaning is explicitly mapped, rather than exporting a procedure as an item.

Issue #4460 tracks examination links and expansion to a build-time registry of
player-facing items, structures, animals and terrain. Exclude/group abstract,
internal and test types. Keep static type metadata separate from live/private
state and reference browsing separate from research/manual acquisition. Generated
coverage and source review do not substitute for native UI or gameplay tests.
