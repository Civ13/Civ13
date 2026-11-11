# Cave dismantling

`python3 scripts/ci_baseline.py unit --suite cave_dismantling` executes the
selected production attack handler through a bounded, fail-closed Python
projection. Species dispatch, runtime lock exclusions and eligibility are source
contracts. The wait, deletion, feedback and stone construction are fake engine
boundaries. These checks are not BYOND compilation or native gameplay evidence.

Covered: ten-stone single yield, 65-tick duration, wrong tool, occupied/stale-empty
population, interrupted retry, reentrant second miner, post-wait population
change/deletion, and a missing-recheck negative control.

Native acceptance still needed: mine empty base/bear/wolf caves with one and two
players; interrupt then retry; introduce population during the wait; confirm one
stone reward and deletion, unchanged species aggression, and no saved action lock
restored after save/load. No native runner or live operations are introduced.
