# Whole cotton insertion audit - 2026-10-29

This follows the recorded variable-dose gap in the
[glass food extraction audit](glass-food-extraction-audit.md). The existing
glass cotton branch converts an entire cotton pile into one cotton reagent unit
per stack unit. It checked only whether any free space remained, then added the
full nominal amount and deleted the pile. A 25-unit pile offered to one free
unit therefore lost 24 paid units.

The branch now requires the complete existing yield to fit the actual holder.
It admits positive whole stock with actual cotton material, then pays through
`stack.use(amount)` before granting output. Failed payment grants nothing.
Exact fills remain allowed; closed, insufficient, invalid or mismatched-material
attempts retain stock and recipient. The ratio and whole-pile interaction are
unchanged; smaller piles can be offered separately. This does not establish a
historical textile-processing yield or introduce new art, research or recipes.

Offline tests execute the actual branch with observable payment adapters. The
new `cotton_insertion.dm` helper joins the existing isolated barrel probe and
selects its existing food suite under added-test admission. It checks actual
beaker/barrel handlers and legal hands, one-unit and preset piles, exact fills,
short/full/closed/small holders, invalid amounts/material and rejected payment.
Normal material/stack consumption and final-hand cleanup remain real; only the
deliberate failed-payment fixture overrides payment to refuse it. The helper,
material definitions and prior controls are retained in fifteen source hashes.
Compile-only runs no world; record hosted runtime separately.

This closes cotton capacity/payment accounting only. The broader crafting audit
remains partial. Candle waits, large-dispenser initial-key ordering and legacy
successful food-state conversions remain separate gaps; cooking/trays and
anvils/workbenches remain other recorded families. Connected graphics, natural
resource access and full-world integration are unverified.
