# Bills of exchange and treasury notes

Code: `code/game/mob/groups/faction_bills.dm`. Tests: `python3 tests/faction_bills/test_source.py`;
native probe `python3 tests/ecology_spawning/run_linux.py . tests/faction_bills/probe.dm`.

Step 8 of the bureaucracy and currency plan. A faction's treasury can issue paper that its strongbox
pays on presentation, so merchants can carry paper instead of sacks of coin.

## Drawing

At the strongbox, anyone with the treasury power (`docs/faction-offices.md`) chooses **Draw bills or
notes**:

- **Write a bill of exchange**: one bill for 1 to 500 silver. It takes one blank sheet of paper from
  the drawer's hands or feet.
- **Print treasury notes**: 1 to 20 notes of one value. The drawer must stand beside a printing
  press, and each note takes a blank sheet.

Each bill is numbered in the faction's register, with up to 200 open bills at a time. A bill whose
number the register does not know, such as a copy or a forgery, is worthless. Examining a bill says
so.

## Redeeming

Anyone, member or not, uses a bill on the faction's strongbox. The box pays from the coin actually
in it, largest coins first, never more than is owed. A fully paid bill is torn up. If the box cannot
pay in full, it pays what it can, and the rest stays owed on the bill until the box is refilled.
Nothing stops a faction from promising more than it holds: the first to redeem are paid, and the
others wait. The ledger shows the coin in the box beside the silver promised on open bills.

The fiat money printer is unchanged.

## Saved state

`map.faction_recruitment["bills"]`: faction -> last serial and open bills (serial -> silver still
owed, drawn by, time). The bill items keep faction, serial and face value in their own vars. Both
are renamed through `faction_roster_rename()`, and the register is cleaned by
`faction_roster_normalize()`.
