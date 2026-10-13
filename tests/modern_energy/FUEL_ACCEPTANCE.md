# Nuclear acquisition acceptance design

Status: design only. No acquisition or processing fixture is implemented here.
PR #3141 remains draft until the production route and these gates are verified.
Ore and radiation code belongs to the radiation owner; this design grants no
permission to change those files or run a local native process.

## Production prerequisites

- Obtain the owner's exact source head, feedstock type, reachable map/terrain
  and safe radiation contract before connecting a route. The uranium branch in
  `code/game/turfs/floor_attackby.dm` is commented out. Cold War map placement
  exists, but no uranium placement was found in Nomads maps during the audit.
- Do not treat ore existence as acquisition. Its constructor starts recurring
  radiation pulses; existing pulses change global radiation. The extraction-kit
  handler deletes the whole stack for five reagent units. Neither behavior is
  an accepted per-unit sealed-cartridge route.
- Define finite input/output amounts and reachable equipment, research, skill
  and era requirements. Electronics or other common materials alone cannot
  produce reactor fuel. Raw ore safety and shielding require owner evidence.

## Acquisition fixture

Reuse the production-body RNG adapters in `tests/mining_yields/probe.dm` if
terrain mining is chosen. Adapt RNG only, not production eligibility or yields.
Check actual supported map modes, era endpoints, legal and rejected terrain,
finite depletion, minimum/maximum paid output and a second attempt producing
no additional feedstock. Include an omission control restoring repeated yield.
Map placement routes instead require actual map-key/coordinate reachability;
placing an item directly in a fixture does not prove that players can obtain it.

## Processing fixture

Run real production procedures with isolated storage and an injected wait/actor
adapter. Check one-unit debit from a multi-unit stack, exact finite cartridge
output, insufficient and wrong feedstock, empty containers and output capacity.
Reject early-era, incomplete research and insufficient-skill actors. Cancel on
actor interruption, input removal, machine destruction and concurrent requests;
each paid unit may commit once and canceled work must not create output.
Use independent omitted-debit and omitted-completion-ownership controls.

Export/import paid inputs and finished cartridges with the native serializer,
including nested containers. Retain durable amounts and reject transient busy
locks, wait owners and reservations on both export and import. Reload during
work must not replay output. Compare global radiation before/after processing
and test the owner's local hazard bounds separately, without disabling them.

## Reactor recipe gate review

`nuclear_power` already requires a geiger-counter prototype and combustion;
the counter maps to `factories`, avoiding a self-dependent prototype gate.
Generator construction additionally requires Modern era and crafting 105.
No reactor or cartridge recipe is currently registered. When the safe route is
accepted, map the reactor and processing equipment to explicit research nodes
before adding material recipes: an unmapped recipe falls back to legacy
thresholds rather than requiring the intended node.
Keep cartridge production tied to paid feedstock processing, not an electronics
recipe. Test catalog visibility and production completion guards with the real
recipe helper, including completed prerequisite and missing node cases.

## Acceptance and evidence

Run pinned BYOND 516.1681 compilation and positive production route, processing,
crafting and native-save fixtures in remote opt-in CI at the same exact head.
Each independent omission control must fail at its intended assertion. Preserve
source head and owner acceptance separately from fixture results. These gates
do not establish full-game reachability, sustained balance, deployment or
long-term memory stability. Capture gameplay only for remaining material
uncertainty under the coordinator's exclusive lease.
