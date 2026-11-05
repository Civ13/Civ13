# Illness pain and body heat

`python3 tests/illness_pain_body_heat/test_source.py` checks that severe illness holds pain under a ceiling (it used to add 3 a second with no limit, reaching traumatic shock at near-full health) and that a body out of the cold only drifts toward the air temperature when that air is freezing.

Not covered: a full in-game run; the fallback and cap are checked from source.
