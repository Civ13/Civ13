# Resuscitation

```
python3 tests/resuscitation/run.py --byond-bin <pinned bin>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless. It checks that a death starts the revival clock and keeps the
person's research knowledge for a revival, that a fresh intact body comes back
alive with that knowledge, and the things that keep a body dead: too long a
wait (or a body loaded from a save), heavy poison, no head, a missing heart or
ruined body, a destroyed brain, rot, a player who has moved on and mapped
corpses. Lethal wounds and blood loss only need treating first. It also checks
the medic examine hint, that adrenaline improves the CPR odds, that brain
damage grows with the time dead but stays survivable, and that the
defibrillator gives the same reasons.

The CPR click itself needs a client for its timed action and is not covered.
