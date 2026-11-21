# Magazine emptying

`test_held_recheck.py` checks that confirming "empty the magazine" only empties
it while the player still holds it and is conscious (#6479). Run with
`python3 -B -m unittest tests.magazine_empty.test_held_recheck`.
