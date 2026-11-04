# Factory automation

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/belts_probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. See `docs/factory-automation-design.md` for the plan this phase belongs to.

`probe.dm` (phase 0) checks:

- Saved belts: load constructs a belt before the saved `dir` is applied, so the load hook must rederive forward and backward directions, including corners, and resume the saved run state. Invalid saved states load stopped.
- Saved switches: position is saved instead of the belt list, a reloaded switch shows its position and reapplies it to its belts, and an invalid position stops them.
- Crate ports: closed crates accept items that fit, merge matching stacks, offer and release filtered items, and never take an item held by a person. Open crates have no port.
- Stamp mill port: plain stone fills the hopper up to its limit, a partial insert splits the stack, and other materials are refused.
- Cable reservations: a repeated draw less than a second after a traversal reuses the published reservation; an older reservation, an overloaded grid or a stopped source takes a full traversal and refuses or releases as before.

Removing the belt load hook's direction rederivation makes three checks fail. Runtime fixture checks do not establish a full disk save and reload, graphical interaction or live balance.

`belts_probe.dm` (phase 1) calls the belt and arm steps directly and checks:

- Belts: idle belts leave the process and dropped items wake them; cargo stays an ordinary floor item, advances up to eight slots a step and crosses to the next belt; the last belt fills a crate; picked-up cargo leaves the belt; a belt facing back blocks and the blocked belt polls slowly; corners enter from the side; a tile carries at most four items; a full crate blocks the line until it has room; runtime state is excluded from saves and a reloaded belt adopts cargo in its saved slot.
- Arms: off or unpowered arms do nothing; a powered arm moves a crate item onto a belt entry and reserves 2 PU; switching off releases demand; a sorting arm without a filter moves nothing and with one moves only matching items into a parts bin; an arm leaves items a bin of another kind would refuse; drill output goes into the stamp mill with the remainder held until there is room; a reloaded running arm resumes without stored time; floor output stops at twelve items.
- Catalog: research gates, the four global recipes and the reused sprite states.

Without the end-of-step rescan, the blocked-belt resume check fails. A local benchmark on 1,922 belts with 2,356 moving items measured about 60 ms per one-second step; it is not checked in because its timing depends on the host.
