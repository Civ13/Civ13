# Party freight

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/party_freight/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. The probe covers safe house depots and party train freight (`code/modules/persistence/party_freight.dm`):

- **Shipping:** Carts research gates the depot. A closed crate next to a depot holding wood, steel, iron ore, leather shoes, hardtack and a crowbar is packed as one shipment of the player's party; the crate and its goods leave the map and the record is text in the depot's saved `freight` field. A crate that also holds a written letter is refused whole and nothing moves.
- **Safe houses:** a second depot in the land lists the same safe house; another party's shipment there stays hidden and cannot be recalled by the player. A record edited to an impossible stack amount is refused.
- **Reload and recall:** a depot rebuilt from its saved field alone still holds the shipment. Recall brings back the same kind of crate, closed, with exactly the six shipped items (the stocked crate kind's own fruit is not added), the same stack amounts, and every item saved with the map again. A recalled shipment cannot be recalled twice.
- **Party trains:** the railway works office saves its `freight`; boots load onto a train, and a faction rename carries both the train's freight and the faction's safe house.

Negative control: encoding untouched items of a travelling family by the literal kind `"type"` instead of their type path refuses the hardtack and crowbar, and the probe fails 9 checks.
