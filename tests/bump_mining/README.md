# Held-pickaxe bump mining

Walking into dense mineable underground rock starts the existing click mining
action. The active held pickaxe wins; otherwise a pickaxe held in the other hand
is used without switching hands. A pickaxe on the back, belt or in a bag does not
qualify. Doors, vehicles, other mobs, constructed walls and nonmineable terrain
keep their prior collision path.

Click and bump share one actor/wall reservation and the existing paid duration
240 / strength coefficient / tool usespeed, survival callbacks and resource
completion. There is no automatic mining loop. Repeated input while the original
wait is active cannot queue another action. Movement including pixel offsets,
loss of the chosen tool, incapacity and turf replacement cancel it. Ordinary
do_after calls have no context and retain their original helper path.

Offline: `-B -m unittest discover -s tests/bump_mining -v` with a verified Python.
`run.py --prepare-only --output <fresh-folder>` extracts production Bump, mining
entry/context and do_after without executing native tools. Remote CI compiles
and runs the baseline and dispatch/reservation/position omission controls with
pinned BYOND516.1681 and retained source/compiler/runtime/result hashes.

The small native fixture adapts human construction, real-client movement
authority, progress display, sound and final resource output; the actual paid
wait, hand choice, Bump dispatch and context procedures run unchanged. It proves
one completion callback, not production mining RNG/yields or connected-client
input/rendering. PR3228's opt-in subtile adapter is not on this master baseline;
pixel-offset cancellation coverage does not establish that transaction's
integration. No local native execution or player-server deployment is authorized.

Restart required: yes. The collision hook and shared mining/wait code require a
rebuilt world and controlled restart before players receive the feature.
