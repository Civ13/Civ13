# Power grid service

## Charging and distribution

Machines and grid batteries use the same reciprocal cable links, including
paired risers and pole spans. An active source may charge a connected battery
across those links, but batteries still cannot charge one another. The charge
budget is shared across storage on the grid and still leaves room for connected
machine demand after existing wire losses. Battery discharge policy is unchanged.

When eligible areas overlap, a machine selects the nearest unobstructed wired
distribution point. Equal distances resolve by map coordinates, then existing
registration order at the same coordinates. Manual wiring takes precedence.
Moving a machine or changing a nearby barrier rechecks eligible points; no
map-wide power scan runs every tick.

## Shortages and priorities

At a connected power meter, **Requested** is currently served load plus
recently refused requests; **Served** is the power currently reserved by loads;
**Shed** shows the portion not served. Idle machines do not count as refused.
The meter displays up to six recently refused loads and plots the last minute.
A connected meter sounds one alarm after five consecutive seconds of observed
shortage and rearms after recovery. It never damages a hub for spare capacity.

Right-click the meter and choose **Toggle nearby machine power priority**.
Select a machine you can reach and that belongs to the meter's grid. A priority
load can reclaim ordinary reservations if it can actually fit; a request too
large for the entire grid leaves ordinary loads alone. If supply drops, ordinary
loads are removed first. Machines retry through their usual update path when
capacity returns. Priority selections reset on restart; normal wiring and
machine configuration do not change. There is no random shutdown lottery.

## Verification

The focused power fixtures cover charging across a riser or overhead span,
foreign and out-of-reach load exclusions, nearest-point ownership, direct
wiring, barriers and movement, failed demand expiry, sustained shortage alarms,
and preemption versus an oversized request. Run only through the authorized
isolated runner. The normal repository checks and pinned compiler can be used
without launching a world.
