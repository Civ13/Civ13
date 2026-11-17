# Skills Guide

- `test_skill_guide.py`: offline source contracts (a row for every skill, no magic, both stat tabs point at the verb). CI suite `skill_guide`.
- `probe.dm`: native probe of the window's contents and the next-recipe lookup:

```
python3 tests/ecology_spawning/run_linux.py . tests/skill_guide/probe.dm 300
```
