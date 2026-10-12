# Active physical training

Stone lifting weights cost eight stone blocks and require Basic Toolmaking.
An agility/endurance course marker costs six wood and requires Primitive
Construction. Both require 30 current crafting skill. These early research
nodes use the existing faction baseline rules. Modern gym weights cost twelve
iron and the gym circuit marker costs eight iron; both require Modern, Factories
and 105 current crafting skill. The material recipe menu and construction action
recheck the era, research and skill gates.

Lifting uses three manually started fifteen-second repetitions. Click the
weights again after each completed repetition. Moving during a repetition, interruption,
unconsciousness, equipment movement/deletion or Stop Exercise cancels the
unfinished set without partial XP. Another player cannot take occupied equipment
and another piece of equipment cannot bypass your current session.

For courses, stand on the marker to start. Walk three tiles east, three north,
three west and three south back to the start. Use Exercise Step at each corner
for its 11.25-second repetition. The four waits total 45 seconds, plus actual
walking. No autonomous loop completes or repeats either activity. Unfinished
claims expire when next used after two minutes. Stop Exercise releases them
immediately.

Completed sets add two points to shared character fatigue, bounded at six.
Six blocks training; one point recovers per running-server minute, evaluated
when training is used. Fatigue is saved, but active sessions and recovery epochs
are not. A restart preserves fatigue and starts a new rest clock.

Early lifting gains 0.5% before 100 trained strength; early courses gain 0.3%
in native dexterity and stamina. Modern equipment uses 0.6% and 0.4% respectively.
At 100 trained skill these base rates halve; fatigue further reduces them.
Native 0.1% rounding applies, with a minimum 0.1% for a completed eligible set.
Early equipment stops at 125 trained/current skill and Modern equipment at 150.
Useful practice and books retain the native 250 cap. No firearm or hostile-target
training is included.

At native strength coefficient one and shovel speed one, ordinary turf digging
in `floor_attackby.dm` takes 4, 6 or 15 seconds in its checked branches and calls
`adaptStat("strength", 1)`, which floors to a 0.6% native increase. Even the
15-second branch can supply four such useful actions per minute. An early lifting
set supplies at most 0.5% per 45 seconds before walking, fatigue or intermediate
reductions. This intentionally keeps useful labor competitive.

`tests/active_training/run.ps1` compiles production sources using BYOND 516.1681
with isolated startup, temporary storage and no listening port. Its wait and
clock adapters accelerate repetitions and inject interruptions; they do not
measure elapsed gameplay or client controls. It tests native stats, cancellation,
reentry/concurrency, physical course positions, caps/fatigue and native whole-world
reload. Genuine existing resource and flag DMI states provide the equipment
graphics. No production-server performance or deployment is established.
