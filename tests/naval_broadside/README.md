# Naval broadside probe

`run.py` checks the captain's broadside order (`code/modules/1713/siege/naval_broadside.dm`):
Naval Battle captains get the boatswain's call, hand firing goes through
`/obj/structure/cannon/proc/discharge()`, guns are found by ship and grouped by
the side they face, and an ordered side fires in a ripple until every gun on it
is empty while the other side and the enemy ship stay loaded.

```sh
python3 tests/naval_broadside/run.py --byond-bin /path/to/byond/bin
python3 tests/naval_broadside/run.py --byond-bin /path/to/byond/bin --negative-control no-discharge   # must fail
```
