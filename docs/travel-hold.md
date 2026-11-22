# Travel hold

Val (2026-11-22): once a trip to another region is confirmed, everyone going is held still and
their things are guarded until the trip is secured or called off. Source:
`code/modules/persistence/travel_hold.dm`.

Trips that hold their travellers, from the moment they are confirmed:

- A trail, a land edge (on foot, riding, leading an animal, pulling a cart, wheeling a bicycle,
  driving a carriage) and a party train or freight trip: everything through `region_gate/travel()`.
- A ship's crossing, on a voyage or from her tiller: everyone on her decks (`hull_tiller/cross()`).
- A flight between continents: everyone aboard the plane (`air_cross()`).
- A crewed lander's launch and a landed lander's flight home.
- An admin's Send Player to Region ([region-admin-send.md](region-admin-send.md)).

While held, a traveller can look around and chat, but cannot move, click, drag, use, drop or
equip anything, and actions in progress stop (`incapacitated()`, `canClick()`). Anyone else
pulling them lets go. Nobody outside the trip may click on, drag, strip or take from a
traveller or anything they wear or carry, touch what they ride or pull, or step onto, reach
onto or move the ship or craft they leave in. Looking (shift-click) still works.

Each trip runs its own checks again while everyone is held. A hold ends when the trip returns:
the travellers either left (the transfer agent recorded the trip, so their characters are safe
in its journal) or stayed and are told they can act again. A hold nothing renews lapses after
15 minutes, longer than a cold region takes to start, so nobody stays frozen if a trip dies.

Not guarded: projectiles, explosions and fire still reach a held traveller or vessel.
