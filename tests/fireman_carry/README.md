# Fireman carry

Hold an aggressive grab on a downed human and click yourself with the grab to
carry them over your shoulders (code/game/mob/grab_carry.dm). Idea from
CM-SS13 (AGPL-3.0); Civ13 reimplements it.

- Offline: `python3 -m unittest tests/fireman_carry/test_source.py`
- Native (pinned BYOND, real humans and grabs on a tiny map):
  `python3 tests/fireman_carry/run_native.py --byond-bin <BYOND bin> --evidence-dir <empty dir>`
  On Linux, `source <BYOND bin>/byondsetup` first. Fixture-only runtimes from
  the stripped startup (observers, ticker, jobs) are expected; the runner fails
  on any missing or failed `CHECK` line or a grab runtime.
