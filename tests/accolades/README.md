# Lifetime accolades

Offline source checks, run by the `accolades` suite in `scripts/ci_baseline.py`:

    python3 -m unittest discover -s tests/accolades

The ledger on the pinned engine, without a client (local records mode):

    python3 tests/ecology_spawning/run_linux.py . tests/accolades/probe.dm 300

- An accolade is met once and claimed once per account; a copy of the same
  claim from another region stores once and pays once.
- A claim staff removed cannot be claimed again; a staff grant pays once.
- Lands are recorded once each; three meet Wanderer.
- Guests, host agents and worlds that keep no characters (and the battle
  world) earn nothing, except First Steps from the tutorial.
- Character progress is cleaned, a year is four temperate or both tropical
  seasons, and progress travels with the character.
