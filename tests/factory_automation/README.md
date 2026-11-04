# Factory automation

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/belts_probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/routing_probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/machines_probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. See `docs/factory-automation-design.md` for the plan this phase belongs to.

`probe.dm` (phase 0) checks:

- Saved belts: load constructs a belt before the saved `dir` is applied, so the load hook must rederive forward and backward directions, including corners, and resume the saved run state. Invalid saved states load stopped.
- Saved switches: position is saved instead of the belt list, a reloaded switch shows its position and reapplies it to its belts, and an invalid position stops them.
- Crate ports: closed crates accept items that fit, merge matching stacks, offer and release filtered items, and never take an item held by a person. Open crates have no port.
- Stamp mill port: plain stone fills the hopper up to its limit, a partial insert splits the stack, and other materials are refused.
- Cable reservations: a repeated draw less than a second after a traversal reuses the published reservation; an older reservation, an overloaded grid or a stopped source takes a full traversal and refuses or releases as before.

Removing the belt load hook's direction rederivation makes three checks fail. Runtime fixture checks do not establish a full disk save and reload, graphical interaction or live balance.

`belts_probe.dm` (phase 1) calls the belt and arm steps directly, with one cabled belt drive covering the fixture, and checks:

- Belts: idle belts leave the process and dropped items wake them; cargo stays an ordinary floor item, advances up to eight slots a step and crosses to the next belt; the last belt fills a crate; picked-up cargo leaves the belt; a belt facing back blocks and the blocked belt polls slowly; corners enter from the side; a tile carries at most four items; a full crate blocks the line until it has room; runtime state is excluded from saves and a reloaded belt adopts cargo in its saved slot.
- Arms: off or unpowered arms do nothing; a powered arm moves a crate item onto a belt entry and reserves 2 PU; switching off releases demand; a sorting arm without a filter moves nothing and with one moves only matching items into a parts bin; an arm leaves items a bin of another kind would refuse; drill output goes into the stamp mill with the remainder held until there is room; a reloaded running arm resumes without stored time; floor output stops at twelve items.
- Catalog: research gates, the four global recipes and the reused sprite states.

Without the end-of-step rescan, the blocked-belt resume check fails. A local benchmark on 1,922 belts with 2,356 moving items measured about 60 ms per one-second step; it is not checked in because its timing depends on the host.

`routing_probe.dm` (phase 2) checks:

- Belt drives: a belt with no powered drive in range stands still and sleeps; a drive that is off powers nothing; a cabled drive reserves 4 PU and wakes the belts within seven tiles while a farther belt stays still; belts stop when the drive's engine stops and resume when it restarts; switching the drive off releases its power.
- Sorting gate: no filter sends everything straight on; a filter sends matching items to the side; the side output can be swapped and feeds a branch belt.
- Splitter: alternates straight and side, and sends everything straight on while the side is blocked.
- Tunnels: an entrance reaches the exit facing the same way up to six tiles ahead and carries cargo under a crossing belt; a missing or turned exit holds the cargo until it is back.
- Saving: drive switch and gate filter and side are saved; drive power, cached drives and splitter alternation are runtime-only; a reloaded running drive regains power on its next step.
- Catalog: research gates, the five global recipes and the reused sprite states.

Removing the belt power check makes five drive checks fail.

`machines_probe.dm` (phase 2b) checks:

- Bloomery: takes up to fifty iron ore and burnable fuel from automation, refuses other items and has no port while unanchored; ore alone waits, fuel starts the smelt and pays its two fuel; the finished sponge iron is offered from the bloomery's tile and can be taken; more ore restarts a fuelled bloomery. Clay kilns stay manual.
- Blast furnace: loads ore and charcoal, starts, and offers only pig iron.
- Powered saw mill: a twenty-log hopper; nothing is cut without power or while unanchored; each powered step cuts one log into twelve planks that merge on the tile and are offered; load clamps and resumes the hopper, which is saved; removing the mill returns its logs.

`fabricators_probe.dm` (phase 3a) checks:

- Recipe list: the five curated rows load with no errors and parse output, inputs, tier and node; every row names a real research node; a missing output, a zero input, a short row and a duplicate are reported and skipped.
- Fabricators: no recipes without research, tier 1 lists only tier 1 recipes and tier 3 lists all; unknown recipes are refused; it takes only its recipe's inputs, up to two cycles each; nothing happens without power; powered steps add progress without spending inputs early; a finished cycle spends one cycle of inputs and leaves the output on the tile, which is offered (honouring arm filters) and can be taken; a power cut pauses the cycle without losing progress or inputs and restored power finishes it; an empty fabricator sleeps and new inputs wake it; a crowded tile makes it wait; the computerized tier runs at half time.
- Lifecycle: every input buffers on its own; load clamps progress and resumes unpowered; the recipe and progress are saved and the active flag is not; load clears a recipe the list no longer has; changing the recipe or removing the fabricator drops its buffer.
- Catalog: each fabricator tier is gated behind its research node.
