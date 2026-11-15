# Huey air assault

`run.py` checks the UH-1 Huey on the Vietnam maps (`code/modules/1713/huey_assault.dm`).

The static checks confirm that soldiers get the Huey note after they are
equipped, that M18 signal smoke can mark the landing zone, and that the art
exists.

The headless probe checks the Huey's whole round trip:

- it is put on a clear pad near the American start;
- only Americans can board it;
- it waits on the ground until it has a landing zone, and a passenger can pick
  any of nine parts of the map;
- signal smoke calls the lift;
- it flies over the roofs with its shadow below;
- it sets the squad down at the smoke and flies home to park;
- smoke popped during the flight waits for the next lift.

Run it, then the negative control:

    python3 tests/huey_assault/run.py --byond-bin /root/byond-516.1688/byond/bin
    python3 tests/huey_assault/run.py --byond-bin /root/byond-516.1688/byond/bin --negative-control no-unload

The negative control sets the squad down back at the pad instead of at the
landing zone, so it must fail.
