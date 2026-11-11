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

Not covered: habitats, hazards and map availability are not source-reviewed per
entry, and generated coverage does not substitute for native UI or gameplay tests.
