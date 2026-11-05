# Space settlement foundations

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/space_settlement/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. The probe covers phase 0 of the [space settlement roadmap](../../docs/space-settlement-roadmap.md):

- **Habitat air ledger** (`code/modules/space/habitat_ledger.dm`): sea-level fill, breathable thresholds, no ticking with nobody inside, capped steps so a long gap cannot replay a backlog, breathing that conserves gas, breach venting that never goes negative, cooling toward the outside, CO2 scrubbing, hatch mixing that conserves gas and weights temperature by volume, resizing, clamped fills, and a saved form of five plain numbers with no time stamps that refuses bad, missing and NaN values.
- **Barren ground and area** (`code/modules/space/barren_world.dm`): the barren area rests on regolith with a dry climate and reuses existing area art and sound; regolith and crater floor have no breathable outside air, a cold ambient temperature, no soil nutrition, no mud and no snow, and reuse the dry-dirt sprite; ordinary ground keeps breathable air and the usual climate.

Nothing in the game creates a ledger or places barren ground yet, so these checks do not establish gameplay, graphics or full-world persistence.
