# Firearm migration evidence inventory (phase 0)

Phase 0 of [the modular firearm plan](https://github.com/Civ13/Civ13/issues/4443).
This is the pre-migration evidence collection step, not a weapon rebalance or
an implementation of modular guns. No gameplay files or save formats change.
Existing `audit-crafting-recipes.py` remains the material-catalog audit; this
companion collects the type/default evidence that catalog rows cannot supply.

## Run it

```sh
python3 scripts/firearm_inventory.py --output /tmp/firearm-inventory.json
python3 scripts/ci_baseline.py unit --suite firearm_inventory --output /tmp/firearm-tests.json
```

The command needs only Python's standard library, reads local sources, and never
starts BYOND, contacts a server, evaluates DM or writes game state. Output is
stable for unchanged source bytes. `--root` accepts another checkout/fixture.
Missing source directories, symlinks, invalid UTF-8 and exceeded bounds fail
instead of emitting a success-shaped partial inventory. Limits: 10,000 files,
4 MiB per file, 128 MiB total input, 50,000 evidence records. Keep reports out of source control; regenerate
against the revision being migrated and retain the source-hash manifest with
review evidence. Source excerpts and expression fragments are capped at 512 characters with
explicit truncation flags. Repeated references to the same path on one line
are deduplicated, preventing a long line from multiplying into enormous output.

## JSON contract, version 1

- `sources`: repository-relative filenames and SHA-256 of exact bytes read.
- `declarations`: one record per absolute standalone type declaration block,
  with file/line, family, selected direct assignments and an unresolved
  inheritance marker. Reopened types stay separate. `lexical_parent_candidate`
  is only a candidate: `parent_type` can override it.
- `assignments`: field name, unevaluated first-line expression fragment, source location.
  Multiline values require reading the original source; fragments are not a
  parsed or necessarily complete expression. Covers
  caliber, ammo/magazine/projectile links, capacity/loading, armor/coverage and
  selected combat tuning fields. It does **not** compute effective values.
- `references`: literal family-path occurrences in factory-named DM files or
  crafting catalogs, including line context. An occurrence can be a type check
  or input, not necessarily a produced item. Comments are excluded; DM string
  literals are excluded from factory path extraction. Catalog strings remain
  candidates for human review, including disabled/custom-format rows.
- `review`: source-located preprocessor directives, unsupported candidate
  headers, space-indented bodies and factory `new`/type-selection expressions.
  This is a review queue, not an exhaustive list of all unknown syntax.
- `summary`: counts of evidence records, not supported recipes, unique types,
  active types, modern weapons or missing definitions.

All clothing is included because armor values occur outside armor-named types.
All gun/projectile eras are included intentionally. Prefix matching alone must
not decide which guns are modern or which clothing protects against bullets.
Family classification is lexical: a type outside these prefixes that uses
`parent_type` to inherit a gun or clothing type will not appear as that family.
The scan visits `code/**/*.dm` and `config/crafting/**/*.txt`; it does not apply
`civ13.dme`, includes or preprocessor conditions. It does not enumerate map
instances, load saved objects, execute recipes or discover arbitrary runtime
construction outside the factory source candidates.

## Review before a gameplay migration

1. **Choose the modern cohort explicitly.** Review declaration blocks and
   acquisition routes; record each included type and excluded historical or
   special weapon with its reason. Preserve old paths and map/save behavior.
2. **Resolve effective defaults using the compiler/runtime.** Follow lexical
   ancestry, explicit `parent_type`, repeated declarations in include order,
   macro conditions and constructor/load mutations. Missing direct fields are
   not missing inherited values. Relative type syntax and dynamic expressions
   need manual or compiler-backed review; this tool must not guess them.
3. **Audit the ammunition chain.** For each selected gun, establish effective
   caliber, magazine type, capacity/load method, casing and projectile mapping.
   Include reload/chamber/ejection, spent casing and restoration behavior.
4. **Audit armor at the damage consumer.** Connect effective armor and body
   coverage to projectile damage/penetration and the human combat handlers.
   Item declarations alone do not prove mitigation behavior.
5. **Audit production and acquisition.** Inspect factory reference contexts,
   dynamic outputs, crafting catalogs, bespoke ammo crafting, job loadouts,
   vending, maps and loot. Generic factory transport does not imply a gun recipe.
6. **Define the component contract before conversion.** Decide ownership of
   receiver/barrel/stock/magazine state, compatibility constraints, derived-stat
   precedence and invalid-component handling. Retain old gun types as adapters
   until conversion and save/load fixtures prove compatibility. Do not persist
   caches or runtime ownership links as component identity.
7. **Gate the first cohort on behavior, not this report.** Compile with the
   pinned engine; verify firing, loading, swapping components, armor interaction,
   factory output and save/load round trips in isolated fixtures, then in-game.
   Compare unchanged historical weapons as negative controls. Roll out a small
   reviewed cohort before broad conversions.

The inventory deliberately has no "migration complete" or "missing field"
verdict. A clean offline run proves only that bounded source evidence could be
collected. Native/in-game validation is a separate requirement for future
behavior changes, not something this phase claims to have performed.
