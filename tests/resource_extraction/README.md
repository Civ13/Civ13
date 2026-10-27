# Resource extraction regression

Run `pwsh -NoProfile -File tests/resource_extraction/run.ps1 -ByondBin <516.1681-bin>`.

The launcher compiles the checkout's production types with ordinary game startup
disabled, removes map includes, and runs a 12 x 12 x 2 constructor fixture in
unique temporary storage. The fixture refuses network ports. The launcher stops
only its own process and removes its unique generated source/build files.
Compile logs, runtime logs, source revision/dirty status, and result metadata
remain in the printed temporary evidence directory.

Coverage includes stack conservation and caps, output congestion, one pending
drill callback after repeated restarts, power reservation release, save/load
hooks, construction side-input transactions, trace gathering eligibility,
replacement identity, river panning, action overlap, and the production
`do_after` movement/active-tool interruption loop. The actual recipe catalog also
proves plain white cable is craftable from one copper before Electricity, while
colored cable stays locked; a production research bench accepts the crafted
prototype without bypassing the remaining study. With startup disabled, consumed
atoms enter the legacy `delayed_garbage` queue; this fixture does not prove GC
drainage or long-running world memory stability.

Circuit-input checks run the real crafting wait and verify that insufficient
iron, lost iron and movement cancellation consume neither input. The catalog
crafts one circuit at a time; a two-output fixture recipe additionally exercises
the shared batch API and its one-iron-per-circuit payment.

Gathering tests shorten the delay. A drill is also serialized to disk and
restored through production entry serialization/loading and post-load hooks;
this is not a full-world round trip. Ordinary startup, crafting menu clicks,
full-length gathering timing, graphical interaction, and production memory are
not established by this fixture. A successful report also requires no runtime
errors in the full runtime log.

## Finite digging regression

`./tests/resource_extraction/run.ps1 -ByondBin <516.1681-bin> -Probe tests/resource_extraction/digging_probe.dm` executes the complete production floor attack handler with an injected action-wait adapter. A competing actor finishes during the first actor's wait; snow, dirt and sand must produce only one output from one remaining unit. Cancellation releases actor locks, and underground mining performs one wait and one conversion. `-DiggingBaseline` substitutes immutable pre-fix floor source at aa675de6dbade0f3740c516dc4b5945c5c9a43c7 and requires the assertions to fail without runtime errors.

The fixture does not establish graphical interaction or elapsed player timing. It leaves cooperative speed/yield balance unchanged. CI selects the existing extraction suite for this PR because it adds an executable integration probe; later edits remain opt-in.
