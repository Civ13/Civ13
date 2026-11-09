# Safe house rooms

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/safehouse_rooms/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. The probe covers safe house rooms and work (`code/modules/persistence/safehouse_upgrades.dm`) and the contacts desk's trader terms:

- **Building:** 10 wood is refused for the stash and none is taken; 35 wood builds it, takes 30 and raises the safe house to 30 shipments. The rooms are a saved depot field, every depot of the land finds them, and another party has none. A closed crate of wood and stone next to the depot builds the kitchen and loses exactly 20 of each.
- **Work:** drying meat needs a kitchen; a depot without the crate finds no meat; drying takes 3 of 4 meat; a room does one job at a time and takes nothing for a second; unfinished work cannot be collected.
- **Records:** the saved text names the party, its rooms and the job; a record edited past level 3 or naming unknown work is refused.
- **Collecting:** after 31 minutes the dried meat is collected at the other depot, once.
- **Contacts desk:** gold alone is refused for level 1; silver and wood from the crate build it, gold in hand builds level 2, and the armourer then pays more and charges less while buying a helmet back still pays at most half its cheaper price.
- **Ownership:** a renamed party keeps its rooms, and a deleted depot's records move to another depot.

Negative control: making `safehouse_consume()` take nothing fails 6 checks (the stash, kitchen, meat, second job and both contacts desk levels).
