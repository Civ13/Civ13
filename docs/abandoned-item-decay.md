# Abandoned debris and long rounds

The source-only season wiring check runs with `tests/abandoned_items/run.py --check-season-wiring`.
It checks both direct custom `seasons()` implementations and the base queued
`season_apply()` worker. `python -m unittest discover -s tests/abandoned_items`
also checks that removing a production clock hook fails verification. These
checks do not compile or launch the game; the native fixture remains separate.

Discarded rubbish and empty, unrecoverable spent casings weather away after **4 actual season changes** on maps with a changing seasonal cycle. Examining debris after **2 changes** warns that it will crumble away. There is no server-hour deadline on those maps. Four changes represent a year in the four-season cycle; wet/dry and ice-age cycles also use the chosen four-change threshold. Startup climate setup does not age debris.

Maps without an active seasonal cycle use **12 hours of elapsed running-server time**, with a warning after **6 hours**. A fixed wet-season label and disabled standard seasons use this fallback. Custom seasonal cycles that run independently of the seasons setting retain seasonal aging. Day/night acceleration and time while the server is stopped do not count. Changing between clocks grants a fresh window.

Admins can force a season change with **Keep decay age** (the default) or explicitly choose **Advance decay age** to count that transition toward seasonal debris aging. Cancel changes neither. Natural scheduled transitions still count. Forced changes do not start another seasonal timer chain. The `seasons(looping, force, advance_decay)` API also defaults forced calls to preservation when its third argument is omitted.

Pick up or move eligible debris to start a fresh recovery window. Backpacks, bags and other native item storage preserve nested contents. Closed native closets/crates preserve contents; open closets dump contents onto the ground. Direct and nested mob inventories, equipped items, active throws, pulled items, anchored/abstract/nodrop items and items containing anything are protected. Arbitrary object locations confer no preservation. Nullspace, pending deletion and unusually deep containment are conservatively protected. A bag remains intended storage even when left on the ground. Native ammunition magazines and guns preserve contained spent casings; dumping those casings onto the ground begins a fresh exposure window. Existing dumpsters deliberately dispose of contents and are not preservation storage.

Only rubbish and spent casings with a defined spent icon and no loaded projectile opt in initially. Money, candles, trays, recoverable arrows/bolts/balls, loaded ammunition, useful tools, component tools, crops, corpses, containers, structures and vehicles are outside this initial scope. No container or child is deleted by this process. Further classes require explicit gameplay review before opting in.

## Scheduling and saves

The native legacy process checks at most 256 candidates every 30 seconds, rotating a single registry. There is no world scan, per-item sleeping decay chain or copied processing list. New waste registers once; Destroy and native Del remove its slot using swap removal. Loaded/recoverable ammunition does not occupy this registry. Actual source revalidates eligibility and protection synchronously before qdel.

For a stable population of N candidates, one sweep requires at most `ceil(N / 256) * 30 seconds` of scheduled time (e.g. 10,000 candidates about 20 minutes, 100,000 about 3.26 hours). Scheduler load and continuous population changes can extend observation/deletion delay; the selected threshold is eligibility age, not a hard deletion deadline. Age begins at the first exposed observation. Movement/inventory/storage hooks reset promptly; direct loc writes are detected at the next observation. A protected transition that occurs entirely between observations through raw loc writes has no guaranteed event history; normal inventory/storage APIs must be used. There is no fixed population-independent sweep latency.

Custom world saves iterate `vars`, including `tmp`. Registry indices, exposure clocks, seasonal counters/mode and location ref-text are explicitly excluded on export and ignored on import. Restored items receive a fresh recovery window; old world-time values cannot cause immediate deletion or replace live registry slots. Only numeric age/counters, a boolean clock mode and text location identity exist at runtime; no additional reference to a location is retained. Save/import resets intentionally favor preservation; admin save/reload cycles can extend recovery windows.

## Verification and limits

Run the versioned production-source probe with pinned BYOND 516.1681:

```powershell
& '<verified-python-path>' tests/abandoned_items/run.py --byond-bin '<516.1681-bin>'
& '<verified-python-path>' tests/abandoned_items/run.py --byond-bin '<516.1681-bin>' --negative-control
& '<verified-python-path>' tests/abandoned_items/run.py --byond-bin '<516.1681-bin>' --negative-control storage
& '<verified-python-path>' tests/abandoned_items/run.py --byond-bin '<516.1681-bin>' --negative-control save
& '<verified-python-path>' tests/abandoned_items/run.py --byond-bin '<516.1681-bin>' --negative-control seasons
```

The fixture compiles the current production sources, disables normal startup and map loading, uses a 4x4 isolated world and temporary saves, and exercises inheritance/lifecycle, direct/nested storage, inventories, warnings, exact 6/12-hour and 2/4-season recovery windows, clock changes, fixed/disabled seasons, native current-format container restoration, stale runtime fields, native Del and mixed batch fairness. It repeats 60 production/disposal cycles of 1,024 items and drains the actual bounded garbage processor with accelerated GC timestamps. Object/reference counts and OS RSS/private bytes are distinct measurements. Forced collection in this probe does not prove that every production reference is naturally released.

This short fixture cannot establish multiweek full-game memory stability, production OOM remediation, allocator behavior under representative maps, or Linux graphical acceptance. No production save, restart, import, telemetry or deployment is authorized by this change. Remaining long-round growth includes legitimate stored resources/equipment, crops/corpses and other non-opt-in live content; broader lifecycle audits and representative full-game measurements remain necessary.
