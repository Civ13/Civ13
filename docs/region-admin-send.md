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
   player is aboard (she goes with everyone and everything aboard, from anywhere on the water,
   logged-out players' bodies included).
2. Choose the destination region. Event regions are left out (use Event Transfer, which keeps
   home characters safe), and so are the TDM barracks and battle worlds, the tutorial and a free
   expedition slot, none of which keeps a character. A ship only goes where a crossing could
   anchor her: a land across the sea, or from there home to the mainland. A sleeping region is
   woken first; a stopped one is refused.
3. Choose the landing (people only; a ship anchors off the coast facing where she came from):
   - **Nearest dry shore**: walking in from the sea on the coasts facing the source land (the
     sea-lane sides), then any coast, the first dry, outdoor, unblocked land tile.
   - **Exact coordinates** `x,y,z`: that tile, or the nearest safe floor within 7 tiles.
   - **Normal arrival point**: where a trail traveller arrives (the trail back, an admin gate,
     a late-join point).
   A destination that cannot land them as asked uses its normal arrival and says so.
4. The dry run is printed in chat: each player is Ready (with what stays behind, such as a horse
   they ride, a cart they pull, or anything the travel record cannot carry) or Refused with the
   reason (dead, inside something, a record too big, the destination stopped or unreachable).
   It also says when an offline character's player is online here in another body.
5. Confirm. Everyone chosen (with a ship, everyone aboard her) is held still at once: they can
   look around and chat, but cannot move, click, use, drop or equip anything, and any action in
   progress stops. The checks then run again while they are held, and anyone who no longer passes
   is let go at once (the admin sees why; the player is told the send was called off). Players
   leave one at a time, three seconds apart, and every check runs again as each one goes. A hold
   ends when the transfer agent has recorded that player's trip and they leave, when their send
   fails, or when the whole send ends; a hold never renewed lapses by itself after 15 minutes. A save here is waited out (up to two minutes) rather than refusing the rest of the
   group. Only one transfer runs per world at a time; an error part way releases it and says so.

Anything the record cannot carry (for example a creature in a bag) is left on the player's tile
here, named with its coordinates in admin chat; the bag and everything else in it go. Wounds
travel limb by limb: each limb's bruising and burns, fractures and lost limbs, and poisoning
arrive as they left, laid on the same limbs as plain bruises and burns, so the trip never breaks,
cuts or severs anything more.

## Audit

Before each player leaves, the world writes their full travel record (items with bag contents,
skills, research, reading, languages, faction, wounds, hunger and thirst) to
`data/transfer-snapshots/<region>-<ckey>-<time>.json` on the source region, so anything can be
checked or restored by hand if a trip ever goes wrong.

Every send is checked 1:1. The source takes a fingerprint of the character (name, skills,
research, scholarship, reading, people and languages, faction, hunger, thirst, poisoning, each
limb's wounds, and every item worn or held with everything inside it at any depth: type, name,
amount, reagents, colour) and sends its digest with the landing, plus one check per part. The
destination fingerprints the rebuilt character and reports either "Everything arrived exactly as
it left" or a warning naming the parts that differ and pointing at the snapshot. Skills are
compared as the record carries them (six significant digits), a coin pile by its coins and
amount, and the faction as the origin the arrival keeps (it rejoins the faction only where it
has a colony). A ship's crew are fingerprinted and snapshotted the same way.
`tests/region_admin_send/probe.dm` sends a character with bags inside bags, a satchel,
waterskins with water, primitive clothing, stacks, a preset coin pile, fractional skills, a cut
leg, a burnt arm, a broken leg, a lost foot, poisoning and two languages through the record and
fails on any difference between the before and after fingerprints.

Every send, refusal at send time, arrival (with the tile and whether the chosen landing was
used) and the player taking their character at the destination is written to the admin log,
shown to admins here, and sent to every region's admins through group admin chat (and so to the
bot's admin channel). "Recent transfers" in the verb lists the last 20 notes in this world.

## From the host or launcher

`shard_group.py --config GROUP players --region ID` lists who is online, where, aboard which
ship, the regions they can go to and the latest transfer notes.

`shard_group.py --config GROUP send-players --region ID --players a,b --to ID [--landing shore|coords|arrival] [--at X,Y,Z] [--ship] [--send]`
answers with the world's dry run. Only `--send` sends: the world holds the players still, runs the
checks again, and answers with that second check's rows and `started` (or a refusal, having let
everyone go). The outcome appears in group admin chat and in the next `players` answer, whose
rows say `held` while a player is held for a send. Both use the region's
loopback lifecycle token (`config/lifecycle-token.txt`), like `epoch`.

The launcher's Host server tab has **Players…** in the selected region's More menu: tick
players, choose the region and landing, **Check (dry run)**, then **Send**. Send stays off until
a dry run for the exact same choice has at least one player ready. After Send the dialog follows
the transfer until it ends, showing the second check and the latest transfer notes.

## Limits

- Both worlds need this build: an older destination ignores the landing and uses its normal
  arrival; an older source has no verb or host request.
- A ridden mount, a led animal and a pulled cart stay behind (a land-edge crossing takes them).
- A ship must be stopped, without an upper deck, and pack like any crossing ship.
