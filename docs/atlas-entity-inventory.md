# Atlas entity candidate inventory

Part of #4460. This is an **audit-only source inventory**, not a replacement for
`UI/crafting-atlas.json`, a player-facing encyclopedia, or a compiled type census.
It extends the absolute-declaration inventory approach used during #3563 without
reopening its delivered recipe work. Existing Atlas fact extraction remains the
runtime catalog's separate metadata source.

## Run

From the repository root:

```sh
python -m scripts.atlas.entity_inventory --output /tmp/atlas-entities.json
python -m scripts.atlas.entity_inventory --summary-only --output /tmp/atlas-summary.json
python tests/atlas_entity_inventory/test_inventory.py
```

Use `--root` to inspect another source snapshot. Record that checkout's revision
and any working changes alongside the report. Outputs are generated on demand;
do not commit a second large entity registry or load this report into the game.
No BYOND installation, constructors, map loading or native execution is involved.

## What it records

- Explicit absolute declarations in `code/` for items, structures, machinery,
  covers, simple animals and terrain. Every candidate retains file/line provenance.
- Direct `name` and `desc` assignments, with literal text, unsupported-expression,
  conditional-source and conflicting-redeclaration statuses. Missing direct fields
  are **not** claims that runtime descriptions are absent.
- A source parent hint from the existing `families.declared_parents` helper.
  Inheritance is deliberately **unresolved**, including parent overrides and cycles.
- Whether each declaration file is referenced by the literal `civ13.dme` include
  graph. Conditions are not evaluated: referenced does not mean active, and
  off-graph does not prove unused or unreachable in another build.
- Exact existing Atlas resource IDs and reverse `resources[*].type` aliases.
  Multiple IDs are marked ambiguous rather than arbitrarily choosing one.
  No duplicated material-to-stack conversion table is introduced.
- Counts of absolute declarations excluded for proc/verb/var paths or outside the
  selected families. Abstract/internal eligibility remains **unreviewed** for all
  candidates, rather than silently discarding types based on names.

The scanner reuses `facts.HEADER`, `facts.VALUE`, `facts.literal` and
`families.declared_parents`. Its comment/multiline masking preserves line numbers
and avoids treating quoted examples as entity definitions. It does not extend
lexical metadata into an imitation DM compiler.

## Deliberate limits and next acceptance step

Relative/nested and inline declaration syntax, non-tab field layout, preprocessing,
macros, escaped/interpolated or multiline prose, constructors, inherited defaults,
map eligibility and actual acquisition remain unresolved. An absent Atlas match
is a documentation candidate, **not** an unobtainable item or missing recipe.
Animals and terrain counts include parent/base/internal candidates, not numbers
of distinct playable species or tiles.

Keep this report out of public UI until eligibility, spoilers and description
quality are reviewed. No private instance names, contents, ownership, hidden
runtime state or character knowledge are read. No save format changes occur.

The existing `tests/sprites/run.py --atlas-assets` exporter is the eventual
compiled validation bridge: it broadens the existing initial-value exporter to
`/obj`, `/turf` and `/mob` without constructing each type. Compiled defaults still
cannot establish dynamic appearances, gameplay reachability or player eligibility.
This PR does **not** execute that native exporter or authorize a live run.

Ten offline fixture tests cover provenance, conditional/dynamic/conflicting
fields, comments, unsupported multiline prose, proc exclusions, literal include
reachability, material aliases, cyclic parent hints and deterministic output.
These tests establish lexical report contracts only.
