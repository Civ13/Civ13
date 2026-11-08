# Tape recorder regression

Run `python3 tests/tape_recorder/run.py --byond-bin <pinned-bin>` on Linux or
Windows; it checks the compiler against `tools/byond/version.json`.
The runner compiles production sources without ordinary startup or maps,
rejects listening ports and uses unique temporary save storage.

Checks cover the Automation research gate for both recipes, loading a cassette,
recording speech in earshot (markup and emotes dropped, out-of-range speech
ignored), recording from a pocket, stop, the tape's time and line limits,
language scrambling for listeners who do not speak the recorded language,
playback finishing on its own, labels, eject, and a native save and reload of a
recorded, labelled tape. They do not cover graphical acceptance or live speech
through a real client.
