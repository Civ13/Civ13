# Two-handed wielding

`test_offhand.py` checks that a two-handed material weapon only wields when the
other hand's item slot is empty and, for humans, that hand is still attached
(#6352). Run with `python3 -B -m unittest tests.twohanded_wield.test_offhand`.
