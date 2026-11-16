# Money changers and a nation's common money

Code: `code/modules/1713/money_changer.dm`; nation votes in `code/game/mob/groups/nation.dm` and
`tools/transfer_storage/nations.py`. Tests: `python3 tests/money_changer/test_source.py`; native probe
`python3 tests/ecology_spawning/run_linux.py . tests/money_changer/probe.dm`; coordinator
`python3 -m unittest tests.transfer_storage.test_nations`.

Second round, step 4 of the bureaucracy and currency plan.

## The money changer's table

6 wood, economy & production, gated on Trade & Coinage (`early_economy`). The first player to use
an unclaimed table can keep it. A kept table locks: only its keeper opens the till, sets rates or
gives it up.

- The keeper puts struck metal coin in the till by using it on the closed table.
- For each issuer's coin the table buys (a faction's mark, or unmarked coin), the keeper sets a
  rate from 1 to 200 percent of the coin's weighed worth (`docs/weighed-money.md`). Below 100 is
  the keeper's margin. Up to 20 rates.
- Anyone else uses coins on the table. It shows what they weigh in at and what it pays, and the
  customer picks which issuer's coin to be paid in, from what the till holds. The table takes
  the coins and pays from the till, largest coins first, never more than owed. If the till can't
  make up the sum in that coin, the trade doesn't happen.
- Examining the table shows the keeper, its rates and what it can pay in.

Nothing is paid that the keeper did not put in or take in trade. An open till lies open to anyone,
like a strongbox.

The strongbox (`docs/faction-treasury.md`) now pays out through the same counter,
`coin_pay_from()`.

## A nation's common money

In the **Nation** verb, a member faction's leader can **Vote on a common money**: the coin of one
member faction, or none. A majority of member factions decides, as for the head. The nation list
shows the common money, and a money changer's table notes it beside that issuer's rate. A faction
that secedes takes its coin out of the nation's common money; a rename keeps it.

The coordinator keeps it in `nation_currency(nation, issuer)`; votes are `nation_vote` rows of kind
`currency`, choice an issuer id or `none`. The registry snapshot carries `currency` and
`currency_votes`.
