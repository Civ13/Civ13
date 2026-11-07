# Time-of-day progress

The Status tab displays the current phase, quarter of that phase, and approximate
minutes until the next phase. A normal example is `Morning (quarter 3/4, ~10 min
until Midday)`. The process counter and configured phase durations are seconds;
this is not the fictional clock time or a countdown until the end of all daylight.

The readout uses the active global cycle, including custom order and Night's wrap.
It leaves the original phase label alone when the cycle is fixed, disabled,
paused, inactive, saving, or has invalid timing/cycle data. Once the existing
transition gate is set, it says `changing to <next phase>` rather than displaying
a new full phase before the old label changes. Reading status never advances the
cycle or changes the saved counter, gate, scheduler, or lighting.

Run the offline focused suite:

    python3 scripts/ci_baseline.py unit --suite time_of_day_progress --output /tmp/time-of-day-progress.json

The full production helper bodies are translated by a bounded explicit adapter.
Every executable line must be recognized. Tests cover quarter/minute boundaries,
all default phases, custom cycles and wrapping, pending/reset and overdue states,
inactive/fixed/invalid inputs, repeated read-only calls, display wiring, and
additive CI selection. A removed-gate negative control confirms that regression
is detectable. No test imports native runners or launches the game.

These checks are source/control-flow evidence, not DreamMaker compilation,
native scheduler/save-load behavior, or connected-client visual acceptance.
Compile with the repository's pinned BYOND toolchain separately. In-game
acceptance should check the row near a natural phase change, a fixed-night map,
and disabling/re-enabling the cycle; it is not performed by this offline suite.
