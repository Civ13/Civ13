# Whole-dose glass food extraction audit - 2026-10-29

This continues the recorded shared-glass follow-up from the
[portable-barrel audit](barrel-ingredient-audit.md). It reviews admission for
the fifteen fixed food-to-reagent branches in `glass/attackby`, inherited by
portable barrels and other glass containers. No new recipe, research gate,
time, art or historical technique is introduced.

The old branches checked only whether any room remained. With one unit of room,
a five-unit grape yield would be clamped to one and the whole grape deleted.
Cinchona additionally lacked a return after the full-container warning, so a
completely full container could consume the plant and produce nothing.

Each branch now requires the actual reagent holder's free space to accommodate
its entire existing fixed yield before creating output or deleting input. Exact
fills remain allowed, and closed containers continue to refuse extraction.
Insufficient room gives a whole-ingredient warning and leaves both the paid
food and recipient untouched. The existing quantities and dispatch ordering
(cod before general raw fish) are frozen in
`tests/furniture_joinery/glass-extraction-routes.json`.

| Existing input | Existing output, units |
| --- | --- |
| Grapes | Grape juice, 5 |
| Cinchona | Quinine, 10 |
| Olives | Olive oil, 6 |
| Juniper | Juniper juice, 6 |
| Animal fat | Lard, 10 |
| Potato | Potato juice, 5 |
| Agave | Agave nectar, 10 |
| Sapote | Sapote juice, 4 |
| Apple | Apple juice, 10 |
| Sapodilla | Sapodilla juice, 10 |
| Cod / general raw fish | Fish, 5 each |
| Rice | Rice paste, 5 |
| Coffee | Coffee, 15 |
| Corn | Corn oil, 5 |

These are existing gameplay conversions, not measured historical extraction
yields or a food-state conservation model. Successful extraction still converts
a whole supported food into its existing fixed reagent recipe, rather than
transferring its arbitrary injected contents. This fix does not establish
freshness, salt, poison or nutrition preservation across that legacy conversion.
Those semantics, variable-dose cotton insertion, lard-candle waits and other
inherited actions remain separate audit work; no shared chemistry change is
included.

Offline tests execute the actual fifteen source branches with inert holders,
checking exact/headroom success, fractional insufficient capacity, full/closed
refusal, actual small-holder capacity and ordinary subtype dispatch. The
existing isolated `--probe barrels` is extended to exercise every frozen route
through actual beaker and barrel handlers, with legal hands and item lifecycle.
Its source receipt includes the food definitions and both frozen catalogs.
Compile-only starts no world; report hosted execution separately. Connected
graphics, natural ingredient access and full-world integration remain unverified.

The broader crafting audit remains partial. This closes the bounded fixed-dose
capacity issue only, following the specialized barrel ingredient fix. Remaining
recorded families include large-dispenser key assignment ordering, cooking/trays,
anvils/workbenches and other material categories. Review ownership again before
starting another implementation family.
