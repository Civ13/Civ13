# Physical land data networks

In the Modern era, craft **land data cable coils** from copper and **land data
terminals** from electronics in the global crafting menu. A data segment is
not a power cable. Existing cable network terminals and landline phones
continue using their original electrical network and do not exchange traffic
with land data terminals.

1. Lay a coil on each floor tile along your route, including beneath both
   terminals. Ordinary land coils work only on dry solid floors. In water,
   use **sealed data cable coils** (copper plus one plastic sheet, requiring
   Electricity research). Sealed segments also work on land and join ordinary
   segments at a same-level shoreline. One coil lays one junction.
2. Wrench a segment to cycle between the four-way junction, straights and
   corners. Examine it to see the open ports. Adjacent segments connect only
   if their ports face each other. No diagonal links. For a paired seabed
   feedthrough, see below.
3. Wire each terminal separately to ordinary electricity by dragging adjacent
   power cable to it, then enable Power. The endpoints can have different
   electrical grids. Each terminal's address is its tile's x.y.z; place only
   one land data terminal per tile.
4. Choose Send, select a recipient address on the connected data cable, and
   type up to 200 characters. The text appears to conscious players within
   three tiles of that recipient. This is not a private message or mailbox.
   Sending is limited to one message per two seconds per terminal.
5. Wirecutters disconnect and recover a segment. A broken path prevents
   delivery unless a different continuous route exists.

The graph is resolved from live segment shapes when selecting and again when
sending. Networks exceeding 256 reachable segments fail closed rather than
routing to a partial set of destinations. Save policy is to preserve physical
segments, their shapes and ordinary terminal power settings, not messages or
computed links. The same terminal coordinates retain the same address after
reload. Moving a terminal changes its address and invalidates the old target.
Local source tests exercise routing; native UI/save-load acceptance is separate.

## Underwater work

Sealed cable is passive and does not provide power. Lay it across a map's
water tiles to connect dry, powered shore terminals. It can also be placed
and serviced on the open seabed level when it exists: reach the segment from
open seabed water using the game's existing free-diving depth limits or
applicable sealed diving suit. Wet and dry sections normally connect at adjacent tiles on the same level.
For a vertical feedthrough, lay two sealed segments at exactly the same x/y,
one on open deep saltwater and one directly below on the map's actual open
seabed. Use a screwdriver on **both** segments to enable their feedthroughs.
Examine them to check whether they are connected. A blocked or missing partner,
a cut, or toggling either end off disconnects the pair. A complete path can
descend from shore, travel along the seabed, and rise at a second pair. Do not
put powered terminals in open water. Other cross-level and all cross-world
feedthroughs are out of scope.

## Follow-up: inter-region submarine backbone, not implemented here

Commission a link only after players install two powered coastal landing
stations and physically lay a continuous paid route across actual adjacent
sea regions. Use durable segment identities and a topology revision, permit
damage/repair, keep passive routes available across sleeping ocean regions,
and require fresh evidence for active endpoints. Queue bounded, short-lived
envelopes over the existing inter-region transport only after both in-game
ends and the physical route validate. Local underwater placement is not an
inter-region link, cross-world messaging, or public internet access.
