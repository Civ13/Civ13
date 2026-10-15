# Nuclear acquisition acceptance design

Status: implemented draft route, with remote native verification in progress.
PR #3141 remains draft until exact-head checks and route acceptance are complete.
The coordinator's 2026-10-15 Decision B permits uranium-only mining, per-unit
processing and local emission changes under the radiation owner's exact-diff
review. No local native runtime or screen lease is granted.

## Production prerequisites

- Modern mineable underground terrain has a finite uranium-only fallback after
  unchanged copper/tin, iron and common fuel outcomes. The archived broad ore
  chain remains commented out. Depletion prevents another uranium yield.
- One raw uranium stack unit pays for one sealed reactor cartridge. Nuclear
  Power research, Modern era and crafting 105 gate both processing and machine
  recipes. Common construction materials cannot substitute for paid uranium.
- Uranium has one local radius-3, severity-7 pulse per second, source-z only,
  with lead shielding and retirement cancellation. Local pulses never increase
  global radiation; default non-ore pulse behavior remains unchanged. Chemical
  extraction consumes one ore unit for the existing five reagent units.

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
The reactor and processor now map explicitly to Nuclear Power and have paid
recipes costing 40 electronics and 20 steel respectively. Neither recipe
substitutes for the cartridge's paid ore processing.
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

The executable `fuel_route.dm` currently covers mining/depletion, processing
payment, interruption/concurrency and retirement, raw-input/cartridge/reactor
native saves, paid output through reactor generation, local pulse recursion,
shielding and callback retirement. Independent debit, completion, recursive
local-flag and retirement-guard mutation controls are wired into remote CI.
Actual ordinary-player acquisition/build/use acceptance remains distinct from
these isolated production procedures, which adapt RNG, waits and actor setup.
