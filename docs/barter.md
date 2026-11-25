# Barter

Code: `code/modules/1713/barter.dm`. Art: `icons/obj/barter.dmi` from
`tests/sprites/create_barter.py`. Tests: `python3 tests/barter/test_source.py`; native probe
`python3 tests/ecology_spawning/run_linux.py . tests/barter/probe.dm`.

Players only: nothing here buys from or sells to an NPC.

## Trade goods

`/obj/item/stack/barter_beads/stone` (1 stone, Regalia) and `/bone` (1 bone, Regalia) are
stackable strings of beads, up to 50, worth trading. Salt piles, pelts, flint and obsidian
tools already serve as goods.

## Barter mat

`/obj/structure/barter_mat` (2 leather, Basic Tools).

- Using an item on the mat offers it: the first two people to do so are the traders, and a
  third is refused. Traders must stand next to the mat.
- An empty hand opens a menu: Agree, Take back my offer, Leave the trade.
- When both traders have agreed, each side's offer drops at the other trader's feet, and the
  trade is logged.
- Any change to either offer clears both agreements, and the other trader is told. An Agree
  response from a menu opened before the change is rejected; examine the revised offers and
  open the mat again to agree.
- A trader who walks away or falls unconscious is dropped from the trade; their offer goes
  back onto the mat's tile.
- Traders, offers and agreements are runtime only. After a load, anything on the mat drops onto
  its tile.
