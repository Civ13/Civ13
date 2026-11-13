# Animal FPS probe

Manual Windows probe for the client cost of many idle animals near a walking
player. Not compiled by CI.

1. Copy `civ13.dme` to `fpsprobe.dme` and append
   `#include "tests\animal_fps_probe\probe.dm"`. Compile it with `dm.exe`.
2. Run `dreamdaemon.exe fpsprobe.dmb <port> -trusted` from a scratch folder
   holding `config/` and connect `dreamseeker.exe byond://127.0.0.1:<port>`.
   Size the map window to about 1280x720.
3. If another Dream Seeker is open (a live server), give the probe window its
   own title first; the sampler measures only the window with that title.
4. Start `sampler.ps1 -RunDir <daemon folder> -WindowTitle <seeker title>` before joining:
   the probe starts its first phase as soon as the client arrives.

Once the round plays the probe moves the client into a human on a clear
Gaia field and runs 20 s phases: walking with no animals, with 80 still
animals, standing among them, walking past 80 plain objects using the same
icons, walking past 80 free animals, and walking with none again.

It writes `probe-marks.json` (server CPU, map CPU and line-of-sight refresh
counts per phase), `profile-<phase>.json`, `client-samples.csv` (Dream Seeker
CPU) and `frames-<phase>.log` (ffmpeg's final `frame=` count over 12 s is
the number of distinct frames drawn).
