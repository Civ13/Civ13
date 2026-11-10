# Durable map field compatibility

The recovery fix accepts the exact legacy 131-field inventory and defaults only
the newly introduced `faction_renames` to a fresh empty mapping. Field version 3
adds `faction_recruitment` (faction recruitment stations, #4237); v1 and v2
saves, declared or unversioned, restore it as a fresh empty list, and a v3
save must carry it. It validates
the complete encoded inventory and graph types before admission, then supplies
the default in a copy of decoded metadata during restoration. Original metadata,
generation markers and restart intents are not rewritten. Existing 132-field
unversioned saves keep their rename data. Captures declare their field version
independently of round/topology schema versions.

Unversioned saves are classified by the known field addition; an old save and an
unversioned new save missing exactly that field cannot be distinguished. Explicit
version 2 requires its 132 fields and version 3 all 133. New captures declare
`map_fields_version: 3`. Unknown field versions, unrelated missing or
extra fields, malformed roots and invalid scalar types remain rejected.

Run `python tests/durable_map_migration/run.py --byond-bin <current-pin-bin>`.
The 4x4x1 fixture compiles complete production sources with startup disabled and
uses the real graph encoder, field validator, capture and metadata restoration.
Frozen v1/v2/v3 inventories are checked without Git history. The legacy fixture
matches `4010a8199b8669b7531e3b0b0c693dd71adc6750` exactly. Synthetic metadata
files exercise validation/restoration, a current metadata disk round trip,
every required-field omission, every wrong root kind, unknown fields/versions,
and preservation of original/candidate bytes and transaction identity. This is
not a production save copy or a complete spatial-world save/load acceptance test.
The fixture closes its port, refuses reopening and rejects clients.

`--negative-control migration` removes legacy recognition; `--negative-control
strict-version` ignores declared field versions. Each must reach its intended
rejection or assertion. Source hashes, dirty diff, compiler/runtime logs and result are
retained in a unique temporary directory. Offline integration checks use
`python -m unittest discover -s tests/durable_map_migration -v`.

## Follow-on policy for new durable fields

Each field addition should declare its first field-schema version, wire type,
and either a reviewed default factory or a required migration. Safe empty
history/cache collections can use fresh empty mappings; ownership, coordinates,
balances and other authoritative state must not receive guessed defaults.
Defaults apply only when reading an older declared schema, never to a missing
required field in a current-version save. Validate the old exact inventory and
types first, normalize a copy, then validate the complete current inventory.
Reject unknown fields and future versions until explicitly supported. Keep
frozen prior/current fixtures plus malformed-save and immutable-input controls
for every migration. Preserve source generations and recovery identity; write
the current schema only during a separately admitted new save. The urgent fix
implements this policy only for `faction_renames`, not a blanket fallback.
