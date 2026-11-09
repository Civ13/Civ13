# Specialist traders

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/specialist_traders/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. The probe covers the specialist trading posts (`code/game/objects/structures/vending/specialist_traders.dm`):

- **Research and prices:** Trade & Coinage research gates all five posts. Every catalogue price is a whole number of the dealer's smallest accepted coin, and every entry has an age range and stock. Every dealer buys back what it sells, and no dealer pays more than half of what any dealer sells an item for. The log prints the price table.
- **Specialities:** bread goes to the provisioner, helmets to the armourer, gold bars and gems to the jeweller, and no dealer buys plain coins as goods. The armourer refuses a helmet at 20% condition.
- **Paying:** copper buys nothing from the armourer and none is taken. Gold in hand and silver in a pocket buy a helmet at the exact price, with change. Two armourer's posts share one stock, and a sold-out item cannot be bought at the other post.
- **Selling:** a helmet is taken and paid for in silver and gold out of the armourer's purse. An empty purse buys nothing until the restock, which refills the purse and stock.
- **Changing coins:** the jeweller turns 100 copper into 9 silver and 5 copper, and hands back too few coins for one gold untouched.
- **Research:** catalogue items gated by a research node are sold only to a buyer whose faction has that node.

Negative control: giving every buyer a 0.7 better buy rate and dropping the cap at half the lowest sale price makes 26 arbitrage checks fail (for example, the armourer buying back a spear for 70 copper after selling it for 90). With the cap kept, the same bonus passes.
