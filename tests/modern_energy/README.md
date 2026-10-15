# Modern energy contracts

See [FUEL_ACCEPTANCE.md](FUEL_ACCEPTANCE.md) for the nuclear route and acceptance
boundary. `fuel_route.dm` executes production mining, paid processing, local
radiation and native-save procedures with isolated actor/wait/RNG adapters.

Run `scripts/check-battery-items.py --probe modern-energy` with BYOND 516.1681
compiler/runtime paths. Add `--negative-control` to omit the solar charge debit in
a generated copy only; the duplicate-charge assertion must then fail.

The runner compiles actual production constructors, solar calculation, lifecycle,
cable supply and battery charging procedures with normal startup/maps disabled.
Temporary runtime storage and a closed port avoid live state. Tests cover day,
night, unknown labels, indoors, wet weather, source debit and expiry, repeated
charging/toggles, accumulator charging, movement/reload exclusions and the registry
cap. Crafting progression is checked by `scripts/check-recipes.py`.
Native entry export/import checks reject forged output/enabled/registration values.
Nuclear source checks cover finite fuel/coolant, wear/maintenance shutdown, eight
local targets at most, distance/z/interior rejection, repeat-interval rejection,
unchanged global radiation and durable native entry state. Route checks cover
Modern underground uranium depletion, research/skill rejection, per-unit debit,
interruption, retirement, same-z access, concurrent work, nested input/cartridge
saves and actual paid cartridge loading into reactor output and saved state.
Independent `--route-negative-control` values are `debit`, `completion`,
`radiation`, `retirement` and `final-interval`; each mutates only generated source and must fail
at its named contract. `--nuclear-negative-control` omits reactor fuel prepayment.
Low/high final fuel and coolant intervals stay usable until normal expiry;
prospective heat/wear limit crossings stop before paying for unusable output.
`preview.py --output <png>` verifies nonempty actual controller DMI pixels without
launching BYOND; it renders a labeled source preview, not a gameplay screenshot.

These are contract tests, not gameplay captures, full-world solar save round trips,
balance acceptance or production performance evidence. Local native runs require
the coordinator's exclusive runtime grant. Current route acceptance requires
exact-head remote CI and owner/coordinator acceptance; draft source alone does
not establish an accepted ordinary-player route.
