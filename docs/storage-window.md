# Storage window

One TGUI window for every container a character can reach. Opening a bag, a
basket or any storage structure opens it, with that container brought into view.

- **You** (left): both hands, worn bags and belt storage, pockets.
- **Nearby** (right): storage structures on the tiles around you, bags lying on
  the floor, the worn bags of anyone unconscious or restrained next to you (under
  "Body of ..."), and loose things on the floor.
- **Moves** (bottom): every move is timed and queued (at most 40). A move takes
  0.3 s plus 0.2 s per size class, half as long to or from your hands, pockets and
  belt, and half again as long out of someone else's gear; the multipliers stack.
  Walking away, being stunned or restrained, or Cancel all stops the queue.

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

Fallbacks: agent characters, a browser that can't run the window, and players
who choose the **Storage Window** verb (OOC tab, saved in preferences) keep the
old HUD strip.

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

The old HUD strip does not search.

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
