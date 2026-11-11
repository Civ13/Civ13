# Fish pen

Low-tech aquaculture for #3051. Code: `code/modules/1713/fish_pen.dm`.

## How it works

- **Build**: craft a **fish pen** from 10 wood (tools, Basic Tools research,
  next to the fishing cage). It is movable like a fishing cage; push it onto a
  fresh-water tile: a lake, river or pond, or a flooded trench or irrigation
  channel that is not salty. Ice and salt water do not count.
- **Stock**: use raw fish you caught (fishing pole, net, sharpened branch,
  fishing cage) on the pen. The first fish sets the species the pen yields.
  Salted fish cannot stock it. Up to 8 fish.
- **Feed**: grain (wheat, cave wheat, oat, barley, rice) adds 2 feed, raw meat
  3, and seeds 1 each (a stack is used up to the cap). Feed holds up to 20.
- **Cycle**: every 5 minutes the fish eat one feed per two fish (rounded up).
  When they are fed and there are at least two, one more fish is born, up to 8.
  Outdoors in winter they eat but do not breed. Three unfed cycles in a row
  cost one fish. A pen that is not in fresh water loses a fish every cycle.
- **Catch**: use any fishing tool on the pen; after 5 seconds you get one fish
  of the stocked species. Leave two to keep it breeding.

## Balance

A full pen eats 4 feed (2 grain) per 5 minutes and, kept at 7-8 fish and fed,
yields about one fish per 5 minutes. That is a steady protein and fat source
that costs farm output, compared with wild fishing, which is free but limited
by each fishing spot's stock. No power, research beyond Basic Tools, or Modern
equipment is needed.

## Saving

`stock`, `feed`, `hungry_cycles` and `fish_type` are saved. The cycle timer's
epoch is runtime-only, and `after_load()` restarts the cycle.

## Verification

`python3 tests/ecology_spawning/run_linux.py . tests/fish_pen/probe.dm 300`
runs 21 native checks: dry refusal, fresh/salt water, stocking, starvation,
feeding values and cap, breeding to the cap, winter, catching, stale timers,
saved vars and load restart.

Not verified: connected-client use and a pen running for hours on a live map.
