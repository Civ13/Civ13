# First-join choices and bottom hover text

- `test_first_choices.py`: offline source contracts (asked before the tutorial, once per account, each question can be cancelled, the bottom hover line is a saved option). CI suite `first_choices`.
- `probe.dm`: native probe of the bottom line's position and the preselected choices:

```
python3 tests/ecology_spawning/run_linux.py . tests/first_choices/probe.dm 300
```
