# Atlas entity coverage

The Crafting Atlas catalog holds two kinds of page. Recipe-linked resources are
the inputs and outputs of recipes and reviewed gathering routes. Reference
entries (`"entity": true`) are every other item, structure, machine, cover,
simple animal and terrain type that declares its own plain name in a file the
build includes; `scripts/atlas/entities.py` decides eligibility. Neither count
is proof of gameplay reachability.

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

## Reference entries (#4460)

- Built at catalog generation from literal declarations only. Nothing is
  compiled, instantiated or read from a running world, so a page never carries
  instance contents, ownership or other live state, and it is not a claim that
  the thing is on the current map.
- A type needs its own literal `name`. A subtype that only changes an icon or a
  value is a variant of its parent and gets no page, and examine never guesses
  a parent or sibling page for it.
- Admin, debug, test, map-plumbing, spawner, effect, projectile and
  hidden-discovery paths are excluded, as is any type whose own name or examine
  text mentions them. Extend `INTERNAL` or `GUARDED` rather than listing types.
- Pages show the name, examine text, kind and declared basics (`facts.py`):
  size, armour, damage, storage, and for animals health, attack, temper and diet.
- Examine shows "View in Crafting Atlas" for any object whose exact type has a
  page and whose name has not been changed. The link carries only the type ID,
  which the existing Topic handler validates. Browsing a page grants no recipe,
  manual or research knowledge.
- `coverage.py` reports reference entries under `reference` (pages, described,
  with stats, with a recipe or route, examine-linkable) and keeps them out of
  the recipe-resource gap list.

- Habitat rows (`habitats.py`) come from the tables the game spawns from: the
  wildlife species table in `ecology_default_species()` (biomes and ground),
  `wild_herb_climates()` and each sea animal's `zone_min`/`zone_max`. They say
  where open-world spawning places a species, not that a map has it.
- Hazard rows come from the reviewed list in `scripts/atlas/hazards.json`. An
  entry covers its type and subtypes unless a subtype has its own entry, and
  names the source lines it was checked against;
  `tests/atlas_habitats/test_habitats.py` fails when those lines change, so a
  reworked mechanic is reviewed again. Add an entry with its evidence when a
  new trap, terrain or animal can hurt players in a way its stats do not show.
- `coverage.py` also counts pages with a habitat and with a hazard.

Not covered: map availability, and animals or plants placed only by map files
rather than by ecology spawning. Generated coverage does not substitute for
native UI or gameplay tests.
