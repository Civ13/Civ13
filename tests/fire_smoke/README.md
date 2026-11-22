# Fire smoke

`python3 tests/fire_smoke/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 12x12 world of
two walled rooms joined by a doorway, checks `code/modules/1713/fire_smoke.dm`:

- smoke fed at a fire fills its room and stops at walls;
- a shut, rated fire door keeps it out of the next room entirely;
- thick smoke blocks sight and thin smoke doesn't;
- it chokes an unmasked person and not one in a gas mask;
- an ordinary shut door lets only a thin wisp seep round it, and an open one
  lets it through;
- indoors, smoke with no fire lingers and then thins; outdoors it clears fast;
- no runtime errors.

It needs the pinned compiler (`bash scripts/cloud_byond_setup.sh`).

The offline source projection for the thin-smoke breathing guard can be run on
this Windows host with:

```
C:\Users\valza\AppData\Local\Programs\Python\Python313\python.exe -B -m unittest discover -s tests/fire_smoke -p test_breathing.py -v
```

It models the breathing helper boundary, including thickness changes after a
callback; it does not execute DM, the native fixture, or measure runtime speed.
