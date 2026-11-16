# Gilding dish

`probe.dm` checks the Bronze Age gilding dish (`code/modules/1713/gilding_dish.dm`):
gold/silver sheets only, grape juice, small items only, power from an uncabled
charged cell beside it (50 PU s per coat), the ten-step coat, a cell carried
away pausing it, load restart, the icon state for each stage (drawn by
`tests/sprites/create_gilding_dish.py`), the Early Chemical Cells gate and the recipe.

- Windows: `./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin>' -Probe tests/gilding_dish/probe.dm`
- Linux/cloud: `python3 tests/ecology_spawning/run_linux.py . tests/gilding_dish/probe.dm`
