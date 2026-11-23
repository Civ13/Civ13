# Worn item restore

Native fixture: a worn pack stays drawn on the HUD across a save and load.

```bash
python3 tests/worn_item_restore/run.py --byond-bin <BYOND bin>
python3 tests/worn_item_restore/run.py --byond-bin <BYOND bin> --negative-control bedroll-state
python3 tests/worn_item_restore/run.py --byond-bin <BYOND bin> --negative-control load-repair
python3 tests/worn_item_restore/run.py --byond-bin <BYOND bin> --negative-control scope-reset
```

Each negative control removes one part of the fix and must fail its own check.
