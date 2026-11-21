# Resin laminate

On Linux, load the pinned BYOND libraries first:

```bash
source '<pinned BYOND bin directory>/byondsetup'
```

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/resin_laminate/probe.dm
```

The probe runs `code/modules/1713/resin_laminate.dm` in the shared resource-extraction fixture. It stands in for the hot press's `do_after` wait and the probe mob's hands, and calls the bakelizer's per-step product proc directly instead of its powered timer.

It checks the following:

- **Bakelizer:** the plastic setting makes plastic sheets, the phenolic setting makes 10 units per step, an empty bucket draws the resin off, and an unknown setting falls back to plastic.
- **Nylon:** the nylon setting spins two skeins of nylon thread per step, the Remove verb hands them out, the setting waits for WW2, and nylon is a material.
- **Hot press:** no resin and three sheets press nothing, an interrupted pressing uses nothing, phenolic resin presses four cloth into two sheets and four silk into three, plain pine resin gives half, and oilcloth is refused.
- **Material:** resin laminate is a material.
