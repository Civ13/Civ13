# Ground pollution tests

- `python3 -m unittest tests/pollution/test_pollution.py` - offline hook checks (suite `pollution`).
- `python3 tests/pollution/run.py --byond-bin <dir>` - native probe on the full source with an
  isolated startup: spread and falloff, decay (rain, trees, grass), the registry, ChangeTurf,
  saved fields and after_load, growth thresholds, crops, wild plant sites, furnace fuel,
  spills and the charcoal cleanup spread.
