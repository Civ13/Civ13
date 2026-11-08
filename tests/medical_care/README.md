# Medical care source contracts

Offline checks for field treatment items and the internal-bleeding/artery
surgery step, plus a check that every medical stack type resolves to an
icon_state that exists in its DMI. They read DM source and DMI metadata only
and do not run the game.

Run: `python3 -m unittest tests/medical_care/test_source.py`
