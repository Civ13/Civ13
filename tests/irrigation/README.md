# Irrigation propagation regression

Run `pwsh -NoProfile -File tests/irrigation/run.ps1 -ByondBin <516.1681-bin>`.
The runner compiles the unmodified production irrigation procedures with small
floor fixtures, a stub icon refresh, and temporary storage. Normal game startup
is absent. It runs with a 15-second deadline and cleans its own outputs.

Coverage includes ordinary-floor isolation, removal and filled-in-channel flags,
fresh sources, flooded trenches, a 72-channel loop, distant salt contamination,
disconnected channels, retained water after source removal, and 100 bounded
refreshes without turf-layer drift. Salt propagation crosses already-wet channels.

`-Revision b43ff97a5a97745f29727e11a29c3783257fd619 -Baseline` reproduces the old
ordinary-floor mutation, ghost source, stopped salt propagation and layer drift.
CI runs both variants on game-selected changes.

This is production-procedure runtime evidence, not a full-game construction,
research, save/load, visual, seasonal or production-memory acceptance test.
The daemon may perform its normal BYOND connection attempt; it does not start
game systems, send game HTTP/Topic requests or read production state.
