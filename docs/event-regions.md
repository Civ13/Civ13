# Event regions

An event region is a world of a region group (shard kind `EVENT`, code in
`code/modules/persistence/region_event.dm`) where admins run events. Players are
sent there and back by an admin; their own characters never leave their land.

## Sending players to an event

In any home region (the mainland or another land), an admin uses **Event
Transfer** (Admin tab) and picks **Send players to an event**:

1. Pick the event region (asked only when the group has more than one).
2. Pick **Everyone** or **Choose players** (add one at a time; Cancel when done).
3. Pick where characters come back: **Where they stood** or **Their bed**.
4. Confirm.

For each player with a living character of their own:

- The character is taken out of play into a hidden event stash on the tile where
  it stood. The stash is invisible, cannot be clicked, pushed, shot, burnt or
  blown up, and does not block the tile. It is saved with the world like any
  other object, so a restart or update during the event keeps the character.
- Nothing happens to the character while it waits: no hunger, thirst, healing
  or illness, and the food it carries does not go off.
- The player is linked to the event region (it is woken first if asleep). Their
  home stays where it was in the world directory.

Players who are dead, in the lobby or observing are just linked. A player who is
riding, driving or inside something stays and is told why; the admin sees the
list of who was not sent.

The world saves soon after (the group's `travel_save_seconds`).

## At the event

Players join the event world with a fresh character, as on any server. Nothing
there is kept: an event region never saves and keeps no homes. **Leave Event**
(OOC) sends a player home at any time.

## Sending players home

In the event region, the admin uses **Event Transfer** again, picks **Everyone**
or chosen players and where they come back (**Where they stood** or **Their
bed**). Each player's own land is told the choice and the player is linked home.
Their character steps out of its stash as they rejoin:

- **Where they stood**: on its own tile, or the nearest safe floor within 7 tiles
  if something was built there meanwhile.
- **Their bed**: beside the bed assigned to the account (Sleep in a bed assigns
  it); where they stood when it has no usable bed.

A player who rejoins their land on their own (a lost connection, Leave Event)
comes back as chosen when they left. After a restart of their land, Persistence's
own return rule applies as for every character (an assigned bed first).

If players cannot come back (the event region closed), the home world's
**Event Transfer** offers **List players away** and **Bring characters back
now**, which puts their characters back into play as offline characters.

## Setting one up

Add a region of kind `EVENT` to the group config with the map the event uses,
run `setup`, and restart the other regions so they learn it (see the
[shard-group README](../scripts/shard-group/README.md#event-regions)). `setup`
writes the shared `config/event-token.txt`: the home worlds and the event world
tell each other over loopback, with that token, where each player came from and
how to return them. The worlds must run on one host.

The launcher's Host tab marks the event region and shows, for each land, how
many players are away at an event.

## Tests

- `python3 tests/event_regions/run.py --byond-bin <dir>` runs the native probe:
  stashing, a hidden and unmovable stash, the stopped clock, and returns where
  they stood, beside a bed, without a bed and onto a built-over tile.
- `python3 -m unittest tests.event_regions.test_sources` checks the hooks the
  probe cannot reach (mob and food loops, rejoin, the EVENT kind).
- `tests/gaia_host/test_shard_group.py` covers the host tool (validation, the
  shared token, `save_minutes` 0, `event_away` in status).
