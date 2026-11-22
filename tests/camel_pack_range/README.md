# Camel pack range

`test_withdraw_range.py` checks that taking an item out of a camel's pack
rechecks the two-tile range after the selection menu, so a camel led away
while the menu is open keeps its cargo (#6720). Run with
`python3 -B -m unittest tests.camel_pack_range.test_withdraw_range`.
