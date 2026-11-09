# Party freight

Val's direction (2026-11-08): players and factions store things in their safe
houses and party trains from Gaia. Like hangars, shipping takes goods out of the
game until they are recalled.

A party is the same as for party trains: the player's faction, or the player
alone. Code: `code/modules/persistence/party_freight.dm`. Test:
`tests/party_freight/probe.dm`.

## Shipments

- A shipment is the item in the player's active hand, or one closed crate
  standing next to the depot or office, with everything inside it (at most 60
  items).
- Every item becomes a record. The extraction equipment codec rebuilds items it
  supports exactly (clothing, guns with their rounds, bags and their contents,
  material tools, some stacks). Otherwise the region travel kinds apply
  (allowlisted stacks and coins, untouched food and medicine, plain tools,
  magazines by round count), then plain material sheets and ore by type and
  amount. Anything else refuses the whole shipment and nothing moves.
- The goods are deleted. The shipment is JSON text in an ordinary saved field
  of the structure that holds it, so a world save carries it with no save code.
  Shipping and recalling wait while a save runs.
- Recall rebuilds the shipment at the player's feet, inside a new closed crate
  of the same kind when it was shipped in one. Rebuilt items are saved with the
  map again.

## Safe houses

`/obj/structure/safehouse_depot` (20 soft wood, Carts research) is built in a
base. Every depot in a land opens onto the same safe house for each party: a
party keeps up to 20 shipments (more with a stash, below) and recalls them at any depot. Nobody else sees
or takes them. Depots cannot be taken apart, burned or blown up; an admin
deleting one is told how many shipments went with it and they are logged.

### Rooms and work

"Safe house rooms and work" on a depot (`safehouse_upgrades.dm`) builds the
party's rooms, three levels each, from supplies in the player's hand and in
closed crates next to the depot:

| Room | Level 1 | Level 2 | Level 3 | Gives |
| --- | --- | --- | --- | --- |
| Stash | 30 wood | 30 wood, 20 iron | 10 iron, 20 steel | 10 more shipments a level (30/40/50) |
| Workshop | 20 wood, 20 stone | 20 iron, a hammer | 20 steel, a wrench | smelt iron; make steel; cast bullets, draw rifle casings |
| Infirmary | 20 wood, 10 cloth | 20 cloth, 10 glass | 10 steel, 20 glass | bandages or gauze; splints; trauma kits |
| Kitchen | 20 wood, 20 stone | 10 iron, 20 stone | 10 steel, 10 glass | dried meat; hardtack; cured ham |
| Still | 20 wood, 10 copper | 20 copper, 10 glass | 10 steel, 20 glass | beer; vodka; whiskey |
| Contacts desk | 10 wood, 100 silver coins | 50 gold coins | 150 gold coins | 5% a level better specialist trader prices, both ways |

Work takes its inputs at once and is ready after a set number of real-time
minutes (20 to 120), so it runs while everyone is offline; each room does one
job at a time, and the goods are collected at any depot of the land. Work
follows the age and the player's research like the traders' stock.

Each party's rooms and jobs are one JSON record in a depot's saved `rooms`
field. Job times are text minutes since 2000, since a JSON number that large
loses digits. A deleted depot hands its records to another depot of the land;
a faction rename carries them.

## Party trains

A finished railway works office (`party_train.dm`) offers its party "Board the
train", "Load what you hold", "Load a crate next to the office" and "Unload a
shipment". A train carries up to 30 shipments in the office's saved `freight`
field. Other parties use the office as before: they can only read why they may
not board.

A faction rename carries both the train's freight and the faction's safe house
shipments.

## Not built

- Freight stays in the land it was shipped from. A party's train berth in the
  rail yard and extraction safe-house accounts do not see it; that would need a
  new transfer agent payload kind.
