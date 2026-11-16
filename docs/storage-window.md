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

Design by Fable (mock-ups in the project files, `storage-window/`). Searching
other people's bags comes next.
