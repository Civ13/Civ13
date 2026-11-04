# Factory automation phase 0

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. See `docs/factory-automation-design.md` for the plan this phase belongs to.

The probe checks:

- Saved belts: load constructs a belt before the saved `dir` is applied, so the load hook must rederive forward and backward directions, including corners, and resume the saved run state. Invalid saved states load stopped.
- Saved switches: position is saved instead of the belt list, a reloaded switch shows its position and reapplies it to its belts, and an invalid position stops them.
- Crate ports: closed crates accept items that fit, merge matching stacks, offer and release filtered items, and never take an item held by a person. Open crates have no port.
- Stamp mill port: plain stone fills the hopper up to its limit, a partial insert splits the stack, and other materials are refused.
- Cable reservations: a repeated draw less than a second after a traversal reuses the published reservation; an older reservation, an overloaded grid or a stopped source takes a full traversal and refuses or releases as before.

Removing the belt load hook's direction rederivation makes three checks fail. Runtime fixture checks do not establish a full disk save and reload, graphical interaction or live balance.
