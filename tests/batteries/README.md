# Battery checks and gameplay reproduction

Use BYOND 516.1681 (the version in CI).

- `pwsh -File scripts/test-batteries.ps1 -ByondBin <bin>` compiles production battery contracts and cable supply against isolated 8x8x1 adapters. Covers bounds, per-second rate, idempotence, full/empty/partial states, consumer reservations, multiple cells, deletion budget reuse, source shutdown, network splits/reconnect and rejection of primary charging or battery-to-battery feedback.
- Run `scripts/check-battery-items.py` with a verified Python executable and `--compiler <dm> --runtime <dd>`. It compiles all real game types, bypasses startup/maps/controllers, and tests production recipe registration, actual electrode/electrolyte interactions, commissioning, durable-field savefile round trip, movement and deletion. Temporary storage and generated binaries are cleaned. This is a battery-state round trip, not acceptance of the repository's full-world serializer.
- `scripts/test-power.ps1 -ByondBin <bin>` retains the normal generator, lamp and radio regression suite.

For genuine gameplay evidence, start from a clean committed checkout:

1. Run `tests/batteries/start-gameplay.ps1 -ByondBin <516.1681 bin> -Port <unused localhost port>`. This builds the actual Nomads game with an opt-in nonce-gated local test adapter, uses fresh temporary config/SQL/storage, disables outbound webhook and Tor-request effects, and records commit/binary hash/PID in its returned `session.json`.
2. Connect a task-owned Dream Seeker to the printed localhost address. Query with `tests/batteries/query-gameplay.ps1 -SessionJson <file> -ByondBin <bin> -Action prepare`. Once status shows state 3, run `join`, then `run` to create the test circuit near the actual Nomad avatar.
3. Run `charge`, wait at least five seconds, then `examine`. Capture the accumulator's rising energy and charging mode. The scene uses a clearly named 20 PU test generator; this validates real battery/cable/consumer behavior, not fuel combustion.
4. Run `discharge`: the adapter stops the generator and invokes the production battery mode interaction. Capture the lamp staying on and energy falling. Record video or timestamped genuine frames for this timed behavior.
5. Run `cut`: the production wirecutter interaction removes the lamp's cable. Capture the lamp going off. Save the tested commit, map/dimensions, query outputs, genuine screenshots/video and replication steps with the PR attachment evidence. Close only the recorded task-owned server and client when done.

Primary jar assembly costs two copper sheets, then a fired clay vase, one iron sheet and 10 units grape juice. Pile assembly costs five copper sheets, then five iron sheets and 50 units grape juice. Primary renewal requires empty energy and replaces consumable electrodes/electrolyte; it is not electrical recharge. Lead-acid costs five lead sheets plus 20 units acid for commissioning and starts empty. Cable research and consumer progression are unchanged. The jar interpretation and the iron substitute in the pile are explicitly speculative/gameplay approximations.
