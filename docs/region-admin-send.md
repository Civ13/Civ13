# Send Player to Region

Admins and the host can move players, or the ship one of them is aboard, from one region of a
group to another without a trail. It replaces hand-run `call_proc` transfers (a temporary gate at
the player's feet and `depart()`), and goes through the same travel record as a trail
(`code/modules/persistence/region_travel.dm`): everything worn and carried, skills, research,
partly read chapters, people and languages, faction, wounds, hunger and thirst. The transfer
agent journals each trip, so nothing is copied or lost if a world reloads.

Source: `code/modules/persistence/region_admin_send.dm`.

## In game (Admin tab > Send Player to Region)

1. Choose who goes: online players (pick one at a time, Cancel when done), a character by
   account (ckey; an offline character waits at the destination for its player), or the ship a
   player is aboard (she goes with everyone and everything aboard, from anywhere on the water).
2. Choose the destination region. Event regions are left out: use Event Transfer, which keeps
   home characters safe. A sleeping region is woken first; a stopped one is refused.
3. Choose the landing (people only; a ship anchors off the coast facing where she came from):
   - **Nearest dry shore**: walking in from the sea on the coasts facing the source land (the
     sea-lane sides), then any coast, the first dry, outdoor, unblocked land tile.
   - **Exact coordinates** `x,y,z`: that tile, or the nearest safe floor within 7 tiles.
   - **Normal arrival point**: where a trail traveller arrives (the trail back, an admin gate,
     a late-join point).
   A destination that cannot land them as asked uses its normal arrival and says so.
4. The dry run is printed in chat: each player is Ready (with what stays behind, such as a horse
   they ride or a cart they pull) or Refused with the reason (dead, inside something, carrying
   what cannot travel, a record too big, the destination stopped or unreachable).
5. Confirm. Players leave one at a time, three seconds apart, and every check runs again as each
   one goes. Only one transfer runs per world at a time.

## Audit

Before each player leaves, the world writes their full travel record (items with bag contents,
skills, research, reading, languages, faction, wounds, hunger and thirst) to
`data/transfer-snapshots/<region>-<ckey>-<time>.json` on the source region, so anything can be
checked or restored by hand if a trip ever goes wrong.

Every send, refusal at send time, arrival (with the tile and whether the chosen landing was
used) and the player taking their character at the destination is written to the admin log,
shown to admins here, and sent to every region's admins through group admin chat (and so to the
bot's admin channel). "Recent transfers" in the verb lists the last 20 notes in this world.

## From the host or launcher

`shard_group.py --config GROUP players --region ID` lists who is online, where, aboard which
ship, the regions they can go to and the latest transfer notes.

`shard_group.py --config GROUP send-players --region ID --players a,b --to ID [--landing shore|coords|arrival] [--at X,Y,Z] [--ship] [--send]`
answers with the world's dry run. Only `--send` sends; the world then answers `started` and the
outcome appears in group admin chat and in the next `players` answer. Both use the region's
loopback lifecycle token (`config/lifecycle-token.txt`), like `epoch`.

The launcher's Host server tab has **Players…** in the selected region's More menu: tick
players, choose the region and landing, **Check (dry run)**, then **Send**. Send stays off until
a dry run for the exact same choice has at least one player ready.

## Limits

- Both worlds need this build: an older destination ignores the landing and uses its normal
  arrival; an older source has no verb or host request.
- A ridden mount, a led animal and a pulled cart stay behind (a land-edge crossing takes them).
- A ship must be stopped, without an upper deck, and pack like any crossing ship.
