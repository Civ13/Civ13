# Interchange Mall design and implementation

This is an original Civ13 shopping-centre raid, inspired by the mall, parking,
service-space and perimeter-extraction concept of Escape from Tarkov's
Interchange. No Tarkov geometry, trademarks, textures or game assets are imported.

## Master plan

All five levels default to 256 x 256, with a generator size parameter supporting
160..512. The raid uses z1 parking/exterior, z4 retail and
z5 upper gallery. z2 private homes and z3 safehouse hub retain their original
96 x 96 layout inside the enlarged level, surrounded by inaccessible walls.
These are separate secure spaces, never stair destinations.

| Level | Spatial role | Main routes |
| --- | --- | --- |
| z1 | Perimeter highways, sheltered parking, loading aisles | Broad drivable perimeter loop, parking through-routes, six stair cores |
| z4 | Hearth furnishings southwest, Foundry hardware southeast, Harvest hypermarket north | Central north-south concourse, east-west shopping street, two side service aisles |
| z5 | Smaller stores, electronics, pharmacy, food court and operations rooms | Gallery loop with cross passages, same six stair cores |

The following coordinates are on a normalized 160-unit design grid, scaled
by the generator for the selected size. Mall envelope x24..136/y24..136.
Six cores at (30,30), (130,30), (30,94),
(130,94), (54,126), (106,126) connect parking to retail and retail to gallery.
Every core is human-only and validates owned raid state, conscious/unrestrained
actor, actual adjacency, source/destination mission level and a clear landing.
Cars never use these stairs. No auto-teleporting vehicle or car clone is created.

Three anchor stores have distinct native floor palettes and named signs.
Hearth has six furnished apartment display suites, a consultation office and
receiving store. Foundry has sales aisles, checkout counters, repair benches,
a stockroom and the reserved hardware cage. Harvest has checkout queues,
broken-up shelf islands and rear bakery, cold storage, receiving, staff and
accounts rooms. The upper gallery contains 20 named shops with separate staff
rooms and distinct clinic, fitting-room, kitchen, office and sales layouts,
plus common dining and two washrooms with toilet cubicles and sinks.

Parking has marked bays, pedestrian crossings, circulation lanes and enclosed
security, maintenance, dispatch and utility rooms. Sixteen wrecks and scattered
debris occupy bays while preserving the road approaches and highway loop.
Fixtures use map-specific variants of existing native structures. Closets and
fridges begin empty; ovens and plumbing are disused. Tool, dismantling and
damage callbacks cannot convert fixed dressing into saleable resources outside
the loot journal. Native furniture on other maps keeps its existing behavior.

Shop rows, shelf ends and side aisles interrupt indoor sightlines. Wide public
concourse routes contrast with narrower service routes; furnishings stay out
of core landings. NPC and loot markers occupy stores on both retail floors.
The bounded existing NPC AI operates locally on each floor; it is not a
cross-level pathfinding system.

## Entries and exits

Two road infil markers at southwest and northeast highway approaches are the
only car arrival candidates. Four additional perimeter markers admit foot raids.
Road vehicle footprints and highway approaches have no dense props.

West and east highway evacuation points support foot and car return. North
rail embankment and east service footgate accept foot extraction only. West
drain access retains the existing no-backpack rule and rejects cars. Exit names
state these restrictions. The existing return journal, fee checks, vehicle
identity, fuel/wear, nested cargo, passengers and private-bay preflight remain
authoritative. Capability checks apply before and after extraction waits.

## Validation stages

The mall is a scavenged post-war site. Every shop contains scattered rubbish,
collapsed masonry, displaced seating and damaged flooring. Parking has abandoned
car wrecks with native 3x2-tile bounds. These props are not usable garage cars or
free loot. The generator restores clear stair landings after dressing; route
checks account for wreck footprints as well as furniture and walls.

1. Generate the deterministic DMM and verify equal dimensions, dictionary and
   atom ordering, protected home/hub contents and all marker types.
2. Flood-fill actual passable cells and stair edges; require every entry,
   exit, shop loot tile, room sign and core to connect, with reachable approaches
   to cabinets, appliances, beds and plumbing fixtures. Check separate vehicle footprint
   paths from both road infils to both highway exits.
3. Compile the selected mall with BYOND 516.1681, then run native traversal,
   raid-floor and vehicle restriction regressions in temporary offline storage.
4. Review genuine in-game appearance and interactions when available. Source
   topology and compilation alone do not establish player readability, driving,
   live-server performance or graphical acceptance.

Generate with the verified Python interpreter and `tests/extraction/build_mall.py`
(optional `--size 320`, for example). The generator adds proportional shelf rows;
scale changes still require layout and travel-time review. 256 x 256 x 5 allocates
327,680 turfs; 512 x 512 x 5 allocates 1,310,720. Wall padding is allocated too.
Generation/topology support is not startup, memory, performance or balance
acceptance for larger sizes. Budgets are 62 ordinary containers plus two keyed
caches, at most
64 allowed container IDs, 2,048 tracked item nodes, 12 NPCs, 32 participants and
16 private homes.
Do not hand-edit the generated map. This map is selectable through the existing
launcher and safehouse next-map catalog; implementation does not deploy it.

All three raid floors have searchable loot containers: six on parking, 16
ordinary plus two keyed on retail, and 40 on the upper gallery. Parking has
workshop salvage in maintenance, dispatch and utility rooms, supplies in the
staff and delivery offices, and ammunition in the security office. These use
the existing first-access tables and journals, not loose-item constructors.
Parking uses IDs 57-60 and 63-64; existing shop IDs 1-56 and keyed IDs 61/62
stay unchanged. A searched source retains its rolled contents and consumed
claims within the loot epoch. Runtime item identities and FIR tracking alone
do not provide durable ownership for loose surface spawns. There is currently
no shelf/counter/ground loot-population system; static renders show scenery
and source containers, not their randomized contents. Native restart recovery
and active-raid acceptance remain separate verification requirements.

Transit security and Foundry hardware each have one exact-key cache on the
retail floor. Their keys can be recovered on any Extraction map and retain
their remaining uses when extracted. See [container keys](extraction-container-keys.md)
for the catalog, acquisition rule and verification boundaries.
