# Gun blueprint design codes

`code/modules/1713/gunsmithing/gun_design_code.dm` and the bench in
`gunsmith.dm`; described in `docs/gun-blueprint-codes.md`.

```
python3 tests/gun_blueprints/test_sources.py
python3 tests/gun_blueprints/run.py --byond-bin <bin> --output <empty-directory>
```

`test_sources.py` is offline: the code is a registered design-code kind, the
bench offers the import and every import goes through `bench_action`.

`run.py` compiles the game without its maps around `probe.dm` and runs it once
with the pinned BYOND. A skilled gunsmith with coins imports codes at a stocked
bench: a whole design becomes a blueprint and its gun, spending the same steel,
wood and 50 silver as designing by hand, and the blueprint exports the same
code. Stocks, receivers and looks from a later age, a caliber the receiver
cannot take, a bare bench, too few coins and an unskilled maker are refused,
and every refusal leaves the bench clear.
