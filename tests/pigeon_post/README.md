# Pigeon post

With the repository's pinned BYOND:

```sh
python3 tests/ecology_spawning/run_linux.py . tests/pigeon_post/probe.dm 240
```

The native fixture verifies exact-home routing from the far edge of the region, the level limit,
blocked and missing lofts, retraining, scalar persistence fields and payload
admission. For client acceptance, craft an outdoor pigeon loft from soft wood,
pull a live pigeon beside it, and select **Train Homing Pigeon**. Lead the bird
outside to a different tile, then use a held sheet on it with Help intent.
Verify that the same pigeon and sheet reach the loft, and repeat with one
closed envelope. Interrupt a release by moving away and check that the sender
still has the letter. Restart a disposable persistence fixture with a trained
bird and loft, then send again.
