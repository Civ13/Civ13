# Synthetic static-source export core

This is an offline canonical JSON validator, deterministic DMM geometry writer
and redacted disposition reporter. It is an initial serializer proof with an
exact wood/iron/chair catalog, not a useful full-world exporter or a working
save-to-map converter. It does not read `.sav` files, inspect a running world,
load maps, invoke BYOND or modify Civ13's DME/maps/configuration.

The only supported input is `kind: synthetic_static_source`, profile
`synthetic-static-v0` and explicit `synthetic_authored_fixture` provenance.
`tests/save_to_map/fixtures/canonical.json` is the complete 3x2x2 example. The
`synthetic_constructor_defaults` declaration is a fixture assumption, never
evidence about an actual object's saved material or flooring. Real-world source,
topology and constructor-default proof are not implemented.

Run from the repository root using a verified Python 3.10+ interpreter. On
Windows, use its full path to avoid the Microsoft Store aliases:

```powershell
& $PythonPath -I -B tools/save_to_map/core.py --input tests/save_to_map/fixtures/canonical.json --output C:/temporary/new-static-package
& $PythonPath -I -B -m unittest discover -s tests/save_to_map -p 'test_*.py' -v
```

The output parent must already exist and be a trusted directory. The package
path must not exist. Existing files/directories, symlinks/reparse components,
hardlinked input, duplicate JSON keys and input/output overlap are rejected.
The input is opened read-only and must end in `.json`; `.sav` is refused before
opening. This is not a hostile concurrent-filesystem containment mechanism.

## Projection and package results

Each cell explicitly supplies x/y/z, one exact allowed turf with a synthetic
default declaration, the allowed area and an ordered object list. Complete
unique in-bounds grids are mandatory. The core permits only exact policy types,
cardinal integer directions and bounded integer pixel offsets. Landmark names
must be the authored `JoinLateCivilian` token. At least one marker must be on wood
floor without a retained structure occupying that tile. This geometric check
does not establish a working job or native spawn.

All variable names and type paths sent to the writer come from fixed catalogs.
String literal encoding escapes backslashes, quotes, interpolation brackets,
newlines and tabs; unsupported controls, booleans, floats and arbitrary objects
are refused. The current policy emits only integers and the fixed landmark
token. Native acceptance of generated literals remains unverified.

- `static_source_only`: complete geometry for this synthetic catalog. Output has
  `geometry.dmm`, `report.json`, `report.txt`, `manifest.json` and a final
  `CORE_COMPLETE.json` receipt bound to the manifest hash. Every result says
  `ready: false`; this receipt confirms offline core output only.
- `rejected`: invalid grid/provenance, unknown terrain/topology, invalid admitted
  properties or an unsupported static object/property. No DMM or completion
  receipt is emitted. Reports contain fixed reason categories and counts.
- `--preview`: unsupported static objects (including unknown subtypes) may be
  omitted with explicit `incomplete_preview` status. An unknown variable with
  unknown semantics makes its whole object unsupported. Preview does not relax
  terrain, topology, input-integrity or required-spawn checks and has no receipt.

Mobs/NPCs and their subtrees, and nested contents of allowed objects, are
transitively omitted with explicit counts. Known identity, credential, user-text
and runtime variables are excluded. No raw input values, unknown type/field
labels, saved identifiers or paths enter reports or exception messages.
Descendants of skipped roots are marked uninspected, with their count unknown.
Report counters describe examined projection before acceptance; a rejected
projection's candidate counts do not mean a map was emitted. Group saturation
preserves exact aggregate/overflow counts.

Output files use exclusive creation and are verified before the completion
receipt. Write errors retain the partial directory without automatic retry.
Failed receipt writes remove only the newly created receipt; if its removal
fails, the result is explicitly `package_write_uncertain` and requires inspection.
Read/decode/IO errors before report construction return a fixed redacted CLI error
and exit 2. Strict rejection or incomplete preview exits 1; complete synthetic
core output exits 0. No exit code establishes compilation or playability.

## Bounds and verification scope

Fixed defaults: 1 MiB input JSON; 2 MiB aggregate output including the receipt;
4,096 cells; eight equal-sized levels; 4,096 objects and 32/cell; 64 fields/record;
65,536 visited data nodes; depth 16; 256 UTF-8 bytes/text value; 64 report groups.
The Python API can select lower test limits but cannot raise these maxima.
Exceeding a bound rejects the projection; output saturation produces a small
fixed rejection report. Unknown/skipped payloads still undergo tree bounds.

Tests execute real synthetic conversions and failure controls, including
determinism, coordinates, object order/multiplicity, literals, credential canaries,
unknown state, budgets, original-byte preservation, exclusive package writing,
injected write/receipt failures and redacted CLI behavior. They neither parse
native saves nor establish native syntax, material reconstruction, complete
topology, startup, rendering, job registration or gameplay acceptance.

See [the proposed companion profile](../../docs/save-to-map/synthetic-profile.md).
The core intentionally emits no metadata/job declarations and changes no DME.
Matching Civ13 code/assets remain required. Native save extraction and real
topology provenance are future work; the profile needs review and separate
source-to-native acceptance before any output can be called playable.
