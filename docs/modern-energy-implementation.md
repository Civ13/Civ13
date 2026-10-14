# Modern solar generation

Solar array controllers require the Modern era, completed Digital Computing,
crafting skill 105 and 20 electronics. Build the controller outdoors, attach
 a cable coil to connect it to a matching adjacent cable, then use the controller
to enable generation. Cut the cable before unfastening it with a wrench.

Clear midday output is 30 PU. Morning and evening output is lower; wet, smog
and extreme weather reduce it further. Indoors, night and unknown time labels
produce no output. Charge accumulators during daylight for later use. The
existing solar_screen DMI state represents the controller.

One shared scheduler supports at most 128 registered generators. Output expires
after one second; delayed processing does not backfill missed generation.
Connected demand is reserved before accumulator charging, and charging debits
each interval's remaining source budget. Toggles and reconnects cannot replay
spent output. Movement, deletion and reload stop generation. Runtime wiring,
registration and charge/output ledgers are excluded from saves.

Solar source commit 602d6654f57308bbfa72c1eb334b69a1cb4b794a passed pinned
BYOND 516.1681 compilation and native isolated generation/storage, crafting,
save restoration and omitted-charge-debit negative-control checks in
[CI run 38408275121](https://github.com/Civ13/Civ13/actions/runs/38408275121).
These checks establish bounded production contracts, not full-game graphical
acceptance, sustained balance or deployment. No local native runtime was used.

Nuclear machinery and its still-unavailable player fuel acquisition route are
separate draft work in [PR #3141](https://github.com/Civ13/Civ13/pull/3141).
