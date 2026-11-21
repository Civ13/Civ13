# Drone destruction

`test_flying_destroy.py` checks that airborne projectile hits run the drone's
break/destroy logic, that a flying drone at zero health is deleted after its
payload drops (the manual release keeps the drone), and that an explosion crash
does not act on a deleted drone (#6656). Run with
`python3 -B -m unittest tests.drone_destruction.test_flying_destroy`.
