# Renewable trace gathering

Finite terrain deposits retain their existing mining behavior. Trace gathering
leaves terrain unchanged and produces much smaller batches.

Use **Crafting > Sift soil for resources** on uncovered non-mineable dirt or sand.
An uninterrupted action yields one unit after three minutes. Basic Toolmaking
unlocks a wooden resource sieve, crafted from four wood; activate it in your
active hand to gather one unit in two minutes. Copper, tin, sand, and stone are
available first, iron from ordinal age 1, and coal, saltpeter, sulphur, and lead
from ordinal age 2.

A wooden bowl held in the active hand supplies **Pan river sediment**. Stand on
eligible soil adjacent to shallow freshwater to pan one copper, tin, silver, or
gold ore in two minutes. Bottled water and salt water do not qualify. Movement,
incapacitation, active-hand changes, and replacement of the worked terrain
interrupt gathering. Panning also checks the original water tile at completion.

Electricity unlocks the industrial drill. Construction costs 20 electronics and
20 steel. Paved Infrastructure unlocks plain white cable, which supplies the
Electricity prototype; colored cables remain locked until Electricity. Connect
an anchored drill to cable power on uncovered dirt at z=1.
It reserves 150 power and produces two randomly selected mineral units every
two minutes. Starting or restarting waits a full interval. It stops when power,
terrain, anchoring, or output space becomes invalid, and releases its power
reservation. Saved drills resume stopped and require manual activation.

Trace gathering and drills fill matching stacks without exceeding their limits.
An output tile accepts at most 12 stacks; existing matching stack space remains
usable at that limit. Clear the tile to continue when no space remains.

The first milestone does not implement automatic river processing or fracking.
Those need separate water/feedstock and power contracts, bounded output, durable
state, and comparisons against finite destructive extraction before acceptance.
