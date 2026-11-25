# Storage window

One TGUI window for every container a character can reach. Opening a bag, a
basket or any storage structure opens it, with that container brought into view.

- **You** (left): both hands, held and worn bags, belt storage, and pockets.
- **Nearby** (right): storage structures on the tiles around you, bags lying on
  the floor, the worn bags of anyone unconscious or restrained next to you (under
  "Body of ..."), and loose things on the floor.
- **Moves** (bottom): every move is timed and queued (at most 40). A move takes
  0.3 s plus 0.2 s per size class, half as long to or from your hands, pockets and
  belt, and half again as long out of someone else's gear; the multipliers stack.
  Transfers between your own carried inventory slots and bags keep their
  timer while you walk. Transfers involving the floor or someone else's
  storage still stop when you walk away. Being stunned or restrained, or
  choosing Cancel all, still stops the queue.

Moving: drag a thing onto a container, or click to select several and press
**Move here**. Enter moves the selection to the container used last. **Take all**
puts things away (first worn bag with room, then pockets, then hands). **Dump
out** asks first, then moves everything onto the floor one by one. Your own bags
have Dump out but no Take all. The find box filters by name.

Server rules: the window names things only by the ids of its last snapshot;
every move re-checks reach, access and room when it starts and when it lands,
and a refused move tells the player why in chat. Locked containers (through
`/obj/structure/storage_container/proc/storage_access_allowed`) show no contents
and no fill.

Hybrid by default: a click on a bag or container opens its classic HUD strip,
another click closes it, and a quick double-click (within half a second) opens
the window. Nothing waits for the double-click: the first click acts at once and
the second one turns it into the window (`/mob/living/human/proc/storage_click`;
`DblClickOn` covers a double-click BYOND reports only as a DblClick). Without a
working window, the second click of a double-click does nothing.
Right-click a bag or storage container and pick **Open Storage Window** to open
the window for it without double-clicking (`storage_window_verb_open`). **Open Storage Window Here** (IC tab, or
right-click yourself) opens it with no bag at all, for the floor, hands and
pockets (`storage_window_show(H, null)`). Players who want the window
every time pick it in Character Setup > Settings ("Bags and containers open
in"), or with the **Storage Window** verb (OOC tab); the choice is the client
preference `STORAGE_WINDOW`. Agent characters and browsers that can't run the
window always use the strip. The first strip a player opens each connection
tells them where the switch is.

## The classic strip follows the same rules

`code/modules/storage_window/storage_strip.dm` keeps the strip from skipping the
window's rules:

- Taking a thing out of a bag through the strip (click or drag) waits
  `storage_window_move_time` to a hand. Moving is allowed if the bag and
  destination are both carried, and the transfer stops if either is dropped.
- Things the viewer hasn't seen show as "?" tiles (`icons/mob/screen/storage_unseen.dmi`,
  states `unseen1`-`unseen5` by size class, drawn by `tests/sprites/create_storage_unseen.py`).
  Opening the strip searches them top first at `storage_search_time` each while
  the viewer stays put with it open. Worn gear is always known.
- Opening a shut crate or closet tips its things out the classic way, so a strip
  player first waits the total search time of the things they haven't seen.

## Searching

Things in a container someone else filled show as grey "?" boxes of their real
size until you have looked at each one. Opening a container (or pressing Search)
looks through it top first: 0.4 s for a tiny thing up to 1.5 s for a bulky one
(`storage_search_time`). Walking away, being stunned or closing the window stops
the search; moves carry on beside it.

- Your hands, pockets, worn gear and the floor are always known.
- Putting a thing into a storage (`handle_item_insertion`) makes it known only to
  whoever put it there (`storage_note_inserted`), so a shared store refilled by
  someone else must be searched again. Members of the inserter's faction
  (`civilization`, kept as `storage_filled_by_faction`) know it too, so a
  faction's own stores never need searching by its members.
- What a player has seen is the item's `storage_seen_by` (keys), a runtime var:
  after a restart everything in other people's containers is unknown again.
- Unseen things are never sent to the window, so they can't be moved, found by
  the find box or taken with Take all. Dump out is off until a container has
  been searched.

The classic strip searches the same way (see above).

Design by Fable (mock-ups in the project files, `storage-window/`).

## Crates, chests and closets

Closets and crates keep their things in their own contents, as before, so every
system that reads closet contents (freight, region travel, safehouses, extraction)
is unchanged. For a player with the window (`closet_storage.dm`):

- Clicking a shut closet opens the lid without tipping anything out and opens the
  window on it; clicking it again closes the lid without sweeping the tile.
  Using an item on an open one puts the item inside.
- An open, unlocked, unwelded closet is listed under Nearby. Crates count things
  (`storagecap`), other closets count size units (`storage_capacity`).
- **Gather** (right-click) queues every loose thing on its tile into it as timed
  moves; **Dump Out** tips everything out after a short wait.
- Packed or mapped contents must be searched like any other container.
- Mobs still go in and out the old way. Mailboxes, coffins, body bags, hideouts,
  sandbags, dumpsters, strongboxes, money changers and extinguisher cabinets keep
  their own behaviour (`item_window = FALSE`).

Players without the window keep the old lid: opening tips things out, closing
sweeps the tile.

## Reasons to build storage

`storage_incentives.dm` gives storage a place in the rest of the game:

- **A tidy room** is a home comfort point (`docs/home-comfort.md`): a container
  in the room and no more than 5 loose things on its floor.
- **Fire**: a flammable container (basket, log chest, wooden crate or closet)
  that burns away takes its flammable contents with it; metal, stone and glass
  things drop out on the tile. Clay jars do not burn. The chance per fire tick is
  the same 27 percent as any other burning object.

## Admin view

**Admin > View Storage** (`storage_admin.dm`) on any container, closet, structure
or mob in range lists everything inside, nested bags included, with each thing's
size, the players who have searched it and the faction that filled it. It is
read-only and marks nothing as seen.

## Racks

`storage_racks.dm` adds open wooden frames, each a storage container that takes
one kind of thing and draws what it holds on its pegs (shrunk overlays at
`rack_spots`, the points the sprites in `icons/obj/storage_racks.dmi` leave free;
drawn by `tests/sprites/create_storage_racks.py`):

| Rack | Research | Holds | Slots |
| --- | --- | --- | --- |
| Peg post | Primitive Construction | hats, clothes, bags, tools | 4 |
| Tool rack | Basic Furniture | tools | 5 |
| Weapon rack | Basic Furniture | weapons, bows, guns, shields | 4 |
| Coat stand | Fine Furniture | coats, cloaks, hats, bags | 4 |
| Clothes rail | Fine Furniture | clothing | 5 |

All are crafted from wood, open the storage window, have Dump Out, count toward
a tidy room and burn like other wooden stores. They take no lock. Food on a rack
keeps no better than on the floor.

## Stack counts on slots

A stack of more than one thing that is held, worn or lying in a bag shows how
many it holds in the top-right corner of its slot, in every HUD style and on
the classic strip (`code/modules/storage_window/stack_count.dm`). A full stack
shows its number in amber, one thing shows nothing, and counts of 10,000 or
more are written short (12k, 1m). Handfuls of rounds show theirs too; anything
else can join in by overriding `slot_count()`.

The number is a shared object in the item's `vis_contents` (never saved), built
from `icons/mob/screen/stack_count.dmi` (`tests/sprites/create_stack_count.py`).
It follows equip, drop, storage and stack use at once, and anything else within
one Life tick. Probe: `tests/stack_count`.
