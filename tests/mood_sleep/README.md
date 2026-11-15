# Mood during actual sleep

Run `python -B -m unittest discover -s tests/mood_sleep -p 'test_*.py' -v`.
The stdlib-only tests reuse `tests/save_movement/source_adapter.py`. They launch
no compiler, game process, network, client, save or native fixture.

All gameplay mood writes use human's `set_mood`/`adjust_mood`: decreases are
discarded when the recipient's `sleeping > 0`; increases remain available.
Resting, lying, paralysis or unconsciousness without sleep do not qualify.
The life tick's upper cap and droid target also cannot lower a sleeper's mood.
On waking, ordinary awake rules resume, including their existing cap/target;
skipped sleep losses are never accumulated or replayed.

`original_writes.json` freezes the 69 original expression statements and their
replacement calls, including duplicates (the six life-tick drift writes moved
into `mood_drift()`, which the maintenance tests project instead; the four
social-trait pushes and the six dirt, flea and sickness drains became
resting-level parts, covered natively by `tests/mood_living/probe.dm`). Tests compare every original/new
expression while awake, and check sleep losses/gains with the real complete
helper bodies. Whole-tree source auditing rejects gameplay writes bypassing
the setter. The full mood maintenance prefix, wake transition, recipient state
and omission/overbroad/frozen-guard controls have separate focused coverage.

This is source control-flow evidence. It does not execute surrounding event
branches, BYOND arithmetic, full Life, actual gameplay, rendering or persistence.
Current sleep entry/exit, physiology and serialization are unchanged.

The `MoodScale` tests cover the shared scale: `mood_tier()` gives each boundary
to the higher tier, Neutral (40 up to 60) has no stat or movement effect, the
sadness flash belongs to a horrible mood only, and no reader keeps its own
ranges. Mood settles at `MOOD_REST` from both sides without overshooting.
