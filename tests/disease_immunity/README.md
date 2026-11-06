# Disease immunity and poison tolerance

`python3 tests/disease_immunity/test_source.py` checks that an illness builds resistance to itself every tick (faster while medicine supports the body), clears once resistance is full and blocks reinfection until it fades, that an untreated severe illness still kills before resistance clears it, and that repeated toxin doses do up to half damage.

Not covered: a full in-game run. `tests/survival` exercises the severe illness rules in a live world but is pinned to BYOND 516.1681 and times out on the current pin.
