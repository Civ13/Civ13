# Faction mints

Code: `code/modules/1713/coin_mint.dm`. Tests: `python3 tests/coin_mint/test_source.py`; native
probe `python3 tests/ecology_spawning/run_linux.py . tests/coin_mint/probe.dm`.

Step 3 of the bureaucracy and currency plan. Copper, silver and gold coins are no longer hand
crafted from a sheet (the three rows are gone from `material_recipes_global.txt`). They are
struck at an anvil with a faction's coin die.

## Coin die

`/obj/item/coin_die`: 1 bronze, economy & production, gated on Trade & Coinage
(`early_economy`). The sprite reuses the blank stamp in `icons/obj/bureaucracy.dmi`. A faction
leader uses an uncut die in hand to cut it with the faction's mark. After that, anyone holding it
strikes that faction's coins, so a stolen die strikes genuine-looking coin. Dies follow faction
renames.

## Striking

Hold the die, stand beside an anvil and use the die on copper, silver or gold sheets. Choose how
many sheets to use and, for silver or gold, how fine the coins should be: 100%, 90%, 75% or 50%.

- One coin weighs one shekel, so a full-weight sheet strikes 10 coins.
- At fineness f, each sheet strikes 10/f coins (rounded down). The rest of each coin is copper:
  `ceil(coins * (1 - f) / 10)` copper sheets are taken from the minter's hands or feet.
- Striking takes 2 s per sheet (at most 20 s), rechecks everything after the wait, and is
  logged.

## Marked coins

Every copper, silver and gold coin stack has `issuer` ("" for unmarked coin) and `fineness`.

- A marked stack is named "*issuer* silver coins". Its description doesn't give the fineness.
- `value` follows metal content: `base * f + 0.1 * (1 - f)`. Research benches, the resource forge
  and the trading balance all count `value`, so debased coins are worth less than they look.
- The trading balance shows debased coins as "debased silver (50% fine)". That is the assay.
- Stacks merge and transfer only with the same type, issuer and fineness. Splits keep the mark.
  Fiat notes of different currencies no longer merge either.
- The coin smelter melts coins by content: ten full coins make one sheet. Copper coins used to
  melt at five to a sheet, which created metal.

Nothing here creates metal or money. Coins come only from players' own metal.
