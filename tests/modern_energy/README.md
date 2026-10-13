# Modern energy contracts

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
unchanged global radiation and durable native entry state. Its fuel/recipe route
is deliberately unavailable pending the radiation owner's safety audit.
`preview.py --output <png>` verifies nonempty actual controller DMI pixels without
launching BYOND; it renders a labeled source preview, not a gameplay screenshot.

These are contract tests, not gameplay captures, full-world solar save round trips,
balance acceptance or production performance evidence. Local native runs require
the coordinator's exclusive runtime grant. Nuclear behavior remains unverified.
