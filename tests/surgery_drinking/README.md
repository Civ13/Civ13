# Drinking versus surgery

Clicking yourself with a bucket on help intent used to print "You are not
skilled enough to perform this surgery step" because `do_surgery()` warned
about any low-quality surgery tool before asking whether the step applied.
Steps now only claim the click when `can_use()` passes, and an open container
aimed at your own mouth always drinks.

- Offline: `python3 -m unittest tests/surgery_drinking/test_source.py`
- Native fixture (projects the production `do_surgery()` into stub types):
  `python3 tests/surgery_drinking/drink_probe.py --byond-bin <BYOND-bin>`.
  Add `--negative-control` to restore the old warning order and confirm the
  fixture fails. It uses DreamDaemon `-safe` on port 0 and does not exercise
  live play.
