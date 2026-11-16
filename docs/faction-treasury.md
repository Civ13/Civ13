# Faction treasuries

Code: `code/game/mob/groups/faction_treasury.dm`. Tests: `python3 tests/faction_treasury/test_source.py`;
native probe `python3 tests/ecology_spawning/run_linux.py . tests/faction_treasury/probe.dm`.

Step 4 of the bureaucracy and currency plan. A faction's money is coin in a strongbox that stands in
the world, so it can be guarded, carried off or pried open.

## The strongbox

`/obj/structure/closet/crate/faction_strongbox`: 10 wood, economy & production, gated on Trade &
Coinage (`early_economy`). It reuses the treasure chest sprite. Until a leader claims it, it is a
plain chest. A faction leader uses it with an empty hand and chooses "Make it the treasury". The
box then anchors and locks. A faction has one strongbox: designating a new one turns the old one
back into a plain chest with its contents.

Keys do not fit a strongbox and it cannot be unbolted. It opens for the faction leader and for
anyone with the faction's treasury power (`docs/faction-offices.md`): an appointed Treasurer, or
whoever holds an in-force seal of an office with that power. Outsiders can pry it open with a
crowbar or hammer: one minute, and every online member is warned. It can also be smashed.

## Menu

- Keepers: unlock and open, close and lock, collect taxes into the box. Sales and business taxes
  still gather in the faction's tax ledger as players trade; collecting turns them into gold and
  silver coin (and whole fiat notes) inside the box. Fractions wait in the ledger.
- Members: collect wages, pay dues with the coins in hand, read the ledger.
- The leader also: set wages, set dues, set sales and business tax (0-30%), release the box (only while open).

Wages are silver a day per account, accrued in real time and capped at 7 days unpaid (at most 50
silver a day). Members collect them from the coin actually in the box, largest coins first,
never more than they are owed; what the box cannot pay stays owed. Dues are an expected amount a
week (up to 200 silver); the box records who paid but forces nobody, players enforce it. The
ledger keeps the last 40 entries.

The stock market's treasury section still sets taxes. Once a faction has a strongbox, the market
no longer withdraws tax funds for it.

## Saved state

The box keeps its faction in its own var. Everything else is in
`map.faction_recruitment["treasury"]`, keyed by faction, renamed through `faction_roster_rename()`
and cleaned by `faction_roster_normalize()`. Nothing creates money: the only coin paid out is coin
that taxes, dues or members put in.
