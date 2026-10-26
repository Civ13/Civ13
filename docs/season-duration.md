# Shared season duration

The shared season scheduler now defaults to **60 minutes** per season, previously
30. Set `SEASON_DURATION_MINUTES` in `config/config.txt` to a canonical number from
1 to 1440; fractional minutes such as `1.5` are accepted. Invalid file values leave
the previous valid/default setting unchanged. The DM API is
`config.season_duration_minutes`; an optional `map.season_duration_minutes` overrides
it, with null meaning inherit. An invalid runtime value falls back to 60 minutes.
The scheduler converts minutes to deciseconds once when it arms its next timer.

Both durable callbacks and the fallback sleeping loop use the same selected
delay and existing singleton ownership. Already pending timers, including saved
durable timer remainders, finish at their original deadlines. Configuration changes
apply the next time a shared season timer is armed; they do not restart a timer.
Map overrides are author policy and are not imported from historical save payloads.

Nomads and Continents retain their existing startup call to the shared scheduler,
which now arms the 60-minute default. Explicit startup `spawn(18000)` calls on
other maps retain their existing first-transition timing; subsequent base-loop
transitions use this setting. Mountain keeps its independent wet/dry 30-minute
loop and a 30-minute inherited initial timer. Ice Age keeps its 15-minute summer,
45-minute winter and 30-minute inherited initial timer. Colonia and Pepelsibirsk
retain their independent calendar-driven behavior. Other literal timers are
unchanged. This patch does not configure independent map calendars.

No season order, weather probability, terrain phase delay, admin force/keep-age
choice, queue coalescing, game-year increment or counted decay transition changes.
Those are separate policies. There is no live configuration write or server update.

Offline checks project the production delay helper and verify unchanged queue,
season, admin, decay and persistence bodies against the recorded base commit.
They do not establish native timer execution. Native testing remains held due to
the uncertain movement launch and denied process inventory; no native runner is
launched by this suite. BYOND compilation and actual timer/reload acceptance are
separate evidence, subject to the existing 2026-10-24 14:48:30 UTC test deadline.
