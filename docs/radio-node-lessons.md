# Radio recipe lessons (issue #4239, phase 5)

On an opted-in Persistence map, select **Present live**, then **Teach recipe node** at a powered radio desk with an adjacent antenna. You must personally know the node and your faction/era must still permit it. Choose one node for a five-minute session. The station has a one-minute cooldown after completion or cancellation.

Up to 32 eligible listeners present at the start can learn. They must remain awake, conscious, active (less than two minutes of client inactivity), and beside the same tuned, powered receiver throughout. Late arrivals cannot join an in-progress lesson. Explicit stop, power and tuning controls clear attendance immediately, including changes reversed between samples. Retuning, losing power, leaving range, going AFK, or losing the research ceiling removes progress. Presenter absence, lost knowledge, missing antenna or a stalled sampling interval cancels the session. No unobserved time is credited.

There are at most 16 simultaneous stations. Sessions are checked every second independently of the ordinary rotating skill-course device list. These are local receiver lessons; cross-region chat relays do not grant knowledge remotely. Lessons, audiences and cooldowns are transient and restart empty after a load. Radio chat and skill courses continue independently. TV node lessons follow in phase 6.

This change does not enable the map flag or deploy anything. It stacks on phases 0, 1 and 4. Phase 3 can refresh its hints from the shared learn callback.

## Verification

`tests/node_broadcast/test_contract.py` is an offline source contract. `tests/node_broadcast/run.py --byond-bin <bin> --compile-only` compiles the full production fixture; it does not execute behavior. The optional native run checks partial/full attendance, late arrivals, AFK, sleep, frequency, power, range, teacher knowledge, research ceiling, long scheduler gaps, cap, cooldown and saved-field exclusion. It adapts startup, physiology/client activity and the clock, and is not connected-client acceptance. `--trusted` is opt-in and requires explicit maintainer permission. It runs no listener port and uses temporary files, with retained logs in ignored `.ci/node_broadcast`.

The development safe-mode attempt reached all 26 behavior assertions, but BYOND denied temporary config/result I/O and the runner timed out. This is not a clean native pass. Trusted-mode execution and connected-client acceptance remain unverified.
