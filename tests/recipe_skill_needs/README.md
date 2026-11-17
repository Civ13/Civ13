# Recipe skill needs

- `test_recipe_skill_needs.py`: offline source contracts (one table, no hard-coded skill checks left in `stack.dm`, the Crafting window and the makeable filter ask the table). CI suite `recipe_skill_needs`.
- `probe.dm`: native probe of which recipes need what, the refusal text and the Voyage exception:

```
python3 tests/ecology_spawning/run_linux.py . tests/recipe_skill_needs/probe.dm 300
```
