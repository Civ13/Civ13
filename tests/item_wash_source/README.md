# Item washing tests

Run the focused source contracts with `python3 -B tests/item_wash_source/test_completion.py`.

The isolated pinned BYOND hide probe exercises the real windlass and shallows
handlers with a deterministic per-piece wait adapter. It verifies the output,
water debit, the source name in the start message, cancellation, and rechecks
when water is drawn or the fitting is removed during a wait.

```
python3 tests/ecology_spawning/run_linux.py . tests/item_wash_source/hide_wash_probe.dm 300
```
