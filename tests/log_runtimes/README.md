# Runtime errors from the live logs

Guards for the runtime errors Gaia's logs repeated most on 14-17 November 2026:
a timer named after a deleted target, built-in `stat()` calls reached from
`Topic`, a material stack without its material, and a reagent without a holder.

- `test_log_runtimes.py`: offline source contracts. CI suite `log_runtimes`.
- `probe.dm`: native probe of the timer name, the reagent and the stack:

```
python3 tests/ecology_spawning/run_linux.py . tests/log_runtimes/probe.dm 300
```
