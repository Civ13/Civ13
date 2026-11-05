# Space settlement foundations

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/space_settlement/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. The probe covers phase 0 of the [space settlement roadmap](../../docs/space-settlement-roadmap.md):

- **Habitat air ledger** (`code/modules/space/habitat_ledger.dm`): sea-level fill, breathable thresholds, no ticking with nobody inside, capped steps so a long gap cannot replay a backlog, breathing that conserves gas, breach venting that never goes negative, cooling toward the outside, CO2 scrubbing, hatch mixing that conserves gas and weights temperature by volume, resizing, clamped fills, and a saved form of five plain numbers with no time stamps that refuses bad, missing and NaN values.
- **Barren ground and area** (`code/modules/space/barren_world.dm`): the barren area rests on regolith with a dry climate and reuses existing area art and sound; regolith and crater floor have no breathable outside air, a cold ambient temperature, no soil nutrition, no mud and no snow, and reuse the dry-dirt sprite; ordinary ground keeps breathable air and the usual climate.

- **Submarine compartment air** (`code/modules/submarine/flooding_controller.dm`): each compartment holds one ledger of sea-level air sized to its deck tiles, and deck tiles carry no air of their own; an empty compartment does not tick, even while breached; water shrinks the air pocket without losing gas and draining restores the pressure; electrolysis stops at the oxygen cap; scrubbers remove only what is there; ventilation shares air between open compartments, conserves gas and skips compartments shut off at the panel; a crew member is counted in one compartment, breathes its air, and suffocates when the oxygen is gone.

Nothing in the game places barren ground yet, and the submarine checks use a bare crew stub on a small fixture, so these checks do not establish gameplay, graphics or full-world persistence.
