# Automated trace extraction

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<BYOND 516.1681 bin directory>' -Probe tests/automated_sifting/probe.dm
```

Production sources run in a temporary constructor fixture with ordinary game startup disabled. A real cable/engine reservation supplies the machines. Tests cover non-mineable sand, repeated restarts, two-unit batches, capped output congestion, power release, freshwater requirements, river removal, inherited stopped load behavior and effective DMI states.

The soil sifter and river concentrator unlock at Electricity and use the same twenty electronics plus twenty steel construction contract as the drill. Both yield two random units every two minutes, leaving terrain intact. Manual gathering chooses one resource but requires uninterrupted player effort; finite deposits still provide much larger mined batches.

The machines reuse conventional grinder and centrifuge graphics from `icons/obj/chemical.dmi`, inspected locally and checked through native `icon_states`. No new art or licensed asset changes are introduced. Runtime fixture checks do not establish graphical interaction, full-world persistence or weeks-long production memory stability.
