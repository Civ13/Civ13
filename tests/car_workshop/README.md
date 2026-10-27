# Automobile construction regression

Run `./tests/car_workshop/run.ps1 -ByondBin <516.1681-bin-directory>`.
The bounded fixture compiles production sources, disables normal startup and
replaces actor initialization and the interaction wait. It uses temporary saves
and never starts a production server. It checks all nine layouts, payment,
material refunds, duplicate wheel delivery, interruption guards, cable demand,
empty tanks, fuelled movement, full rotations and production world-save import.
Logs and commit/dirty metadata remain in the printed temporary evidence directory.

This establishes the tested production procedures. It does not establish human
interaction usability, occupied driving, live multiplayer or production memory
behavior. The normal map-spawn path retains its existing behavior.
