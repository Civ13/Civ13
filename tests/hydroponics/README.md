# Hydroponics trays

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/hydroponics/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. A real cable/engine reservation powers the trays, and the probe calls the tray's bounded `advance()` step directly instead of waiting on the processing scheduler.

The probe checks the crop whitelist and one-seed planting, water fills that credit only water actually removed and leave other reagents in the donor, compost nutrient, the combined 60-unit reservoir, unpowered and power-cut pauses that keep progress, completion-time payment of 2 water and 1 nutrient per cycle, at most one stage per step, six cycles to a ready crop, power release and no expiry once ready, one-time harvest of two seeds and the produce, nutrient and water shortages, the fragile tomato/bean dry death and its reset, roof shelter and snowstorm exposure, saved and runtime-only variables, load clamping, cable rejoin and single registration, the frame's glass and cable payments, the Agriculture-tree research gate (never granted by era alone), the steel recipe and every reused sprite state.

Trays reuse existing art: `kevlar_trough_empty` in `icons/obj/structures.dmi` and the crops' own growth states. Runtime fixture checks do not establish graphical interaction, full-world persistence, live balance or the real scheduler cadence.
