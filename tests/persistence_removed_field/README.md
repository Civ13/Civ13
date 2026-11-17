# Saves with removed fields

`python3 tests/persistence_removed_field/run.py --byond-bin <BYOND bin>` compiles
the production game with normal startup disabled, saves a fixture object with a
field set, simulates the removal of that var in the type var cache, and loads
the world again.

Gaia's handover on 2026-11-17 failed because its save still held research
benches' `tier_progress`, which a later update removed: the import stopped on
"Undefined variable". The loader now skips a saved field the current code no
longer has, logging it once per type, and keeps the rest of the object.

`--negative-control no-removed-field-skip` disables the skip and must fail.
