# Factory automation

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/belts_probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/routing_probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/machines_probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/chemistry_probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/pipes_probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/vessel_probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/packaging_probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/meter_probe.dm
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/factory_automation/plating_probe.dm
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
- Wrenching: arms, drives, fabricators and the monitor can be unwrenched; an arm that is off turns both ways by verb, a running arm refuses to turn or be wrenched, and an unfastened arm or drive does no work.
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

- Recipe list: the thirty-six curated rows load with no errors and parse output, inputs, tier and node; every row names a real research node; a missing output, a zero input, a short row and a duplicate are reported and skipped.
- Fabricators: no recipes without research, tier 1 lists only tier 1 recipes and tier 3 lists all; unknown recipes are refused; it takes only its recipe's inputs, up to two cycles each; nothing happens without power; powered steps add progress without spending inputs early; a finished cycle spends one cycle of inputs and leaves the output on the tile, which is offered (honouring arm filters) and can be taken; a power cut pauses the cycle without losing progress or inputs and restored power finishes it; an empty fabricator sleeps and new inputs wake it; a crowded tile makes it wait; an item recipe makes a screwdriver and offers it, and a stack recipe makes three rifle casings from one copper; the computerized tier runs at half time.
- Lifecycle: every input buffers on its own; load clamps progress and resumes unpowered; the recipe and progress are saved and the active flag is not; load clears a recipe the list no longer has; changing the recipe or removing the fabricator drops its buffer.
- Catalog: each fabricator tier and the stack arm are gated behind their research nodes.
- 3D printer (Digital Age): lists nothing before 3D Printing is researched, then only the twelve tier 4 printing rows; older fabricators cannot run them; it buffers two cycles of plastic and prints a hardhat from three plastic in three powered seconds.
- Stack arm (phase 3b): draws five power units; with no filter it moves ten items of the first kind in one swing, never mixes kinds in a batch and takes only its filter when one is set; a sorting arm with no filter still moves nothing and a feeder arm still moves one item a swing.

`chemistry_probe.dm` (phase 0 of `docs/chemistry-automation-design.md`) checks:

- Oil well: no port off a spring; takes one barrel with room and starts extracting; offers it only when full (honouring arm filters); taking it stops extraction and frees the well for the next barrel.
- Refineries: a petroleum barrel is drained and, once empty, becomes the output barrel; feed fills the refinery to its limit and the drained barrel waits on its tile, blocking more feed until it is taken; with an output barrel, feed and cable power the refinery starts itself once and reserves its power; a full output barrel is offered, and taking it stops the refinery and releases power; the barrel list and refine loop are runtime-only, load restores the held barrel and leaves the refinery stopped, and removal releases the barrel. The biofuel refinery takes olive oil and ethanol (at its purity) and refuses other barrels.
- Engines: no port without a connected fuel tank or while unsecured; a barrel of a fuel the engine burns tops up the tank and waits on the engine's tile; the tank itself is never offered.
- Barrel station: inert tank; no port while unsecured; drain mode empties a barrel and holds it until taken, one at a time; fill mode fills an empty barrel; a locked station offers nothing; removal releases the held barrel.
- Reagent gate: no filter sends everything straight on; a reagent or "empty" filter sends matching containers to the side and anything else straight on; the filter is saved.
- A powered feeder arm carries a drained barrel from a station into a refinery.
- Catalog: research gates, the two global recipes and the reused sprite.

Removing the station's `NOREACT` flag makes the inert-tank check fail.

`pipes_probe.dm` (chemistry phase 1) calls the network step directly and checks:

- Networks: a line of pipes joins the station, tank, engine and pump next to it into one network, and pipes draw straight runs and junctions; nothing moves without a running pump; a cabled pump draws its power and moves twenty units a step, sinks before buffers; a full sink lets the holding tank fill; a filtered tank refuses other reagents and the network goes idle, then looks again within five steps; a sink draws from a holding tank; a closed valve splits the network and an open one rejoins it; a filling barrel station draws from the network; a switched-off pump releases its power.
- Wrenching: pipes and fluid machines can be unwrenched; an unfastened tank and pipe have no role, ask for a rebuild and leave the network, and fastening them again rejoins it.
- Water intake: beside open water it supplies the same mix a person filling a container there gets; away from water it supplies nothing.
- Refinery: draws petroleum from an oil well's barrel through pipes; a full refinery's output barrel feeds a gasoline-filtered tank while petroleum stays in the well.
- Saving: a pipe's network is runtime-only; valve, pump switch and tank filter are saved and pump power is not; reloaded pumps and pipes rebuild the networks; holding tanks are inert.
- Plumbing: a new water tap and piped shower start dry and a dry shower will not turn on; a tap holds what the pipes bring it, sickness included; a piped shower takes only water; nothing is made along the way; filling a container empties the tap by as much; a running piped shower uses its water and turns itself off when it runs out; taps are inert.
- Habitat machines: an electrolyser takes only the room it has from a water recycler through pipes, at the pump's rate; both pipe only water; the recycler saves its water but not its pipe holder.
- Steel barrels: a barrel beside a pipe stays off the network until wrenched, and one away from pipes cannot be fitted; a fitted barrel joins as a source only, feeds a tap at the pump's rate and draws a pipe joint; the fitting is saved; moving the barrel or wrenching it again detaches it and it keeps its water; wood barrels never join.
- Catalog: research gates (including the tap and piped shower), the five global recipes and the reused sprites.

Letting a network move reagents without a powered pump makes four checks fail. Dropping the recycler's settling of what the network took makes both habitat transfer checks fail.

`vessel_probe.dm` (chemistry phase 2) calls the network and vessel steps directly and checks:

- Network: an idle vessel joins its network and takes nothing without a recipe; with one it wants whole batches of the recipe's inputs and nothing else; it draws a full batch in ratio from filtered tanks; the full batch waits unreacted and takes no more until the vessel has power; a cabled vessel draws power while it reacts, reacts the whole batch after three powered steps and releases its power; the product leaves through the pipes and the next batch starts filling.
- Catalysts: batches leave room for catalysts; a batch one unit short never reacts; catalysts stay in the vessel and are never offered; once the product is out the vessel refills inputs only; a new recipe flushes old catalysts; the vessel is inert.
- Reaction sites: a heated recipe runs only in a powered vessel; the reaction bench still needs its burner; bench-only recipes still do not run in a loose beaker; the bench and vessel share one recipe list.
- Saving: recipe and stage are saved, power and reaction time are not; a reloaded vessel restarts its reaction time unpowered and rejoins the networks.
- Catalog: the Factories gate, the global recipe and the reused sprites.

Letting catalysts leave the vessel makes two checks fail; letting heated recipes run in an unpowered vessel makes one fail.

`packaging_probe.dm` (chemistry phase 3) checks:

- Bottler: with no reagent set it takes nothing; it takes only open containers holding nothing but its reagent, one at a time, and offers nothing while filling; it fills from the pipes, offers the container once full and draws no more; an arm can take it; a removed bottler drops its container.
- Automatic tablet press: it buffers calcium carbonate and aspirin in tablet ratio and nothing else, filled through pipes; unpowered it presses nothing; powered it presses an aspirin tablet of one carbonate and four aspirin paid from the buffer; it stops when the buffer runs out and waits once twelve items lie on its tile; before the tablet era it presses and draws nothing.
- Vessel tiers: the fast and industrial vessels hold 400 and 1,000 units and react a full batch on the first powered step.
- Saving and catalog: the bottler's reagent is saved and press power is not; a reloaded press rejoins the press list; the press buffer is inert; research gates, recipes and reused sprites.

Offering a bottler's container before it is full fails two checks; letting the press buffer fill without keeping the tablet ratio fails five.

`meter_probe.dm` (chemistry phase 4) checks that a pipe meter off the pipes says so; on a network it counts pipes and pumps, shows stopped and running pumps and last step's flow, lists tank fill and filters, the vessel's recipe, stage and fill, and other machines' pipe roles; its dial lights only while liquid moves and goes dark when the network idles; a reloaded meter rejoins the meter list and is never a network member; and its research gate, recipe and sprites. Lighting the dial whenever the meter is on a network fails two checks.

`logistics_probe.dm` (phase 4a) checks:

- Fast belts: a fast belt takes two steps a tick and joins the fast list; on a six-tile line cargo on fast belts reaches the crate in about half the steps of plain belts (3 against 6); a fast run hands cargo on to plain belts; an empty fast belt sleeps and leaves the fast list; the assembly lays and returns a fast belt; Automation gates it.
- Wagons and carts: an arm loads a transport wagon until its eight slots are full and a full wagon refuses more; an arm unloads it; filters limit what it offers; a tender takes only fuel; a shopping cart loads from and unloads to automation.
- Factory monitor (phase 4b): a rate counts what it has seen, rolls into the previous minute and averages over the window, and reads zero after two idle minutes; the monitor lists the loading arm as waiting with the eight items it moved this minute, a fabricator without inputs as starved with its recipe, the belt drive as running and a summary of the belts in range; its page shows the table; Automation gates it.

`plating_probe.dm` (electroplating) calls the plating bath's process directly and checks:

- Refusals: stacks, non-metal material weapons and already plated items are refused; a bath without an anode sheet or five units of sulphuric acid will not start.
- Coating: an uncabled bath makes no progress; a cabled bath reserves power, finishes after five powered steps, renames, tints and adds value (gold +30, less than the sheet's 40), uses the anode and five units of acid, then releases its power. A coat in progress restarts after a load, and progress and power are not saved.
- Wear: tin halves and copper takes a quarter off the health a weapon, tool or shield loses; gold and silver do not.
- Automation: pipes fill only sulphuric acid; arms hang one sheet, lower an item in and take the coated item out.
- Catalog: the bath unlocks with Electricity, has a global recipe and reuses existing sprites.

Fixture checks do not establish graphical interaction, a full disk save and reload, or live balance.
