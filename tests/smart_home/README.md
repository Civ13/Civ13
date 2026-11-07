# Smart hub regression

Run `python3 tests/smart_home/run.py --byond-bin <pinned-bin>` on Linux or
Windows; it checks the compiler against `tools/byond/version.json`.
The runner compiles production sources without ordinary startup or maps,
rejects listening ports and uses unique temporary save storage. A test actor
supplies an identity in place of a connected client's ckey.

Checks cover the Smart Home research node and recipe gates, cable-network
pairing (another network is refused), owner/resident/guest rights and faction
sharing, the wake name, fixed commands for lights, plugs, smart locks, status,
device lists, time and timers, the reply rate limit, a satellite speaker, the
smart lock's resident hand unlock and power-loss behaviour, and a native save
and reload of hub settings, pairings, lock state and a running timer. They do
not cover graphical acceptance or live speech through a real client.
