# Train collision investigation

The minimal probe extracts the train base and movement procedures directly from `code/modules/1713/trains.dm`. It replaces audiovisual resources with null and supplies isolated no-op effects/map adapters; it does not start the full game. Run `./tests/train_collision/run.ps1 -ByondBin <BYOND-bin>`.

Baseline master 0d38999d5 on Windows BYOND 516.1669: adjacent wagons A/B with A.connected=B and B.connected=A, then A.Move to the next turf, produce `Maximum recursion level reached` in check_connections/Move. The END marker is not reached; the 15-second watchdog terminates the owned process. This is a recursion runtime and stalled fixture, not demonstrated native process crash or production diagnosis. CI uses 516.1681.

The hitch verb can form this reciprocal cycle when two adjacent cars face each other: hitch A to B, then B to A. Unhitch currently clears the wrong car's connection. Failed parent movement also continues to pull followers. Automated collision separately stops and damages the moving train.

Gameplay screenshots and movement video are required before acceptance. Screen control is paused; fixture output does not substitute for game evidence.
