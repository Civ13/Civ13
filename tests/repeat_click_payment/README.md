# Repeat-click payment checks

Stopping rule: offline source-order checks only; no native world, client or saves.

A lagged second click is handled while the first click's prompt or build wait
sleeps. These checks keep each listed path re-checking its material, target
and reach after the sleep, and paying with `use()` in the same step, so two
answers cannot both build or both pay. Run:

```
python3 -m unittest tests.repeat_click_payment.test_source
```

The mould pour also has native cases in `tests/stone_molds/casting.dm`. The
other paths are not exercised natively or in-game.
