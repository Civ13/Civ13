# Isolated native train station proof

This manual fixture observes extracted production train movement from commit
`ec86e58fa67fdd7baea265d8716a64ae6f9a2d99`. Its video is a **native simulation
sprite replay, not a DreamSeeker client recording**.

The powered engine uses the production locomotive timer and start/stop methods.
Seven following base-wagon instances use production hitching, following and
collision procedures, with real train sprite states. Audio, lighting, map
restrictions, persistence, rider/cargo hooks and game startup have explicit
fixture adapters. Wagon storage constructors, crafting UI, player input and
full-game/client behavior are not established by this fixture.

Cases cover the main bypass, passenger siding, depot loop and service stops;
both split switches, all four orientations of the craftable left-turn rail,
vertical/horizontal rails, lever radius, detached-car rotation, eight-vehicle
junction clearance, missing forward guards, blocked side targets, track ends,
opposing switches and fuel exhaustion. The service berths are x6..13,y1 and
x25..32,y-8. At the depot merge an eight-vehicle consist needs the engine at
x44 before its tail clears x36. Stops at target tiles are scripted operator
actions using the real locomotive stop method, not automatic signals.

The independent oracle compares native observations against geometric routes,
predecessor old-tile positions, coupling identities, headings, health and
ordered controls. Its synthetic unit data is validator test input only. A
coherent fabricated trace is not authenticated by this oracle alone: actual
run/source/workflow identities, pinned toolchain members, process and cleanup
receipts, artifact hashes and media inspection are required as well.

Offline controls use only Python's standard library and mocked effects:

```sh
python3 -I -B -m unittest discover -s tests/train_station_cloud -p 'test_*.py' -v
```

No compiler, daemon, Docker command, dependency installation or remote action
runs during these unit tests. The manual workflow executes these controls
before the separately admitted native observation.

The existing `train-collision.yml` workflow is manual-only. Select `station` and
supply the exact reviewed candidate head and tree; the host checks its public GitHub
repository, branch/workflow identity and first attempt. It uses one immutable
386 image, the pinned 516.1688 archive and a nonroot, read-only, network-none
container. Native work is one bounded compiler and one bounded daemon, followed
by owned cleanup. The native trace has at most 1,024 events. Preinstalled
ffmpeg/ffprobe/libx264 capabilities are checked read-only before native work;
the replay has at most 1,200 frames and 8 MiB, with exact frame-count validation.
No automatic retry is provided.

The pre-existing canonical train-collision job is retained under the separate
`collision` profile. It is skipped when `station` is selected; the station proof
does not implicitly run the other native fixture.

Artifacts retain source binding, raw native/failure logs, run and process
receipts, cleanup outcomes and, after successful native validation, the video
and provenance. The schematic replay holds observed tile positions at 2x speed
with no interpolation; control states have real native dwells. It does not
prove client pixels, client timing, full-game save/load or production readiness.
