# Character slots

Part of the lifetime points plan (accolades are in `docs/accolades.md`). An
account can keep up to four characters, buying slots 2 to 4 with lifetime
points. Code: `code/modules/accolades/character_slots.dm`; the owner key
helpers are in `code/modules/persistence/player_reclaim.dm`.

## Rules

- Slots 2, 3 and 4 cost 100, 200 and 300 points, bought in order. Spent points
  stay spent; accolades are never taken back by buying.
- Only a Discord-verified account (`account_verified`, or a launcher sign-in)
  can unlock or play an extra slot. At every lobby login an unverified account
  plays slot 1 and its other characters stay asleep. Fails closed.
- One character in play at a time: a client plays one slot.
- Switch (OOC > Characters) only while the current character sleeps in their
  own bed (Sleep), or from the lobby once the body has had no player for 30
  minutes. A slot left cannot be played again for an hour.
- No switching while the character is restrained, wanted or outlawed (any
  warrant in `faction_justice.dm`), near a cell door with time left, or was
  hurt by someone in the last ten minutes (`round_fact_hit_time`).
- The idle body stays where it rests. Homes, beds and death legacy are per
  slot (owner keys below).
- Kin are public: examining a character names the account's other
  characters. Splitting one group into several factions, or using kin, to get
  around claim limits is structuring. It is not allowed, and admins will step
  in to break it up. Kin sharing one faction is enforced by the player houses
  plan.

## The character lobby on Persistence

Completing Sleep in a valid assigned bed opens a private character picker.
Reconnecting to that sleeper also opens it, after the usual saved-body
ownership checks. Its Wake up button uses the usual 30-second Wake Up action;
opening the lobby does not wake, move, or protect a body. A normal awake
reconnect still returns directly to the character.

The picker shows the account's slots with a short status, and a Skills table
of base stats for each uniquely identified local body. The optional gateway lobby lists the
account's known names and slots without claiming a body. Use **Continue**
on the current character's card to route the active slot. The destination still checks admission;
an unavailable or travelling home does not send this choice to a substitute
region. Opening the lobby from a bed does not bypass injury, restraint,
warrant, jail, or save/recovery checks.

Choosing a different slot takes you to your current character's land. Complete
the switch with its existing **OOC > Characters** action so that land can check
whether it is safe to leave the body behind. This version does not change the
active slot from the gateway or replace a missing remote body. New character
customization and creation still happen at the destination's Join screen.
The character lobby is not a playable world and is not enabled on round-based
gateways.

## Structuring

- One leadership seat per player: a character cannot found or be handed a
  faction while another character of the same account leads one
  (`faction_kin_leads_elsewhere` in `faction_membership.dm`).
- Each player counts once: kin living in one province give one resident's
  stake (`province_stakes`), and a siege's member count counts each player
  once (`province_siege_block`).
- Court marks follow kin: a warrant or outlawry against one character shows
  when examining the account's other characters (`justice_kin_accounts`).
- Province caps count a whole bloc (`code/modules/provinces/province_blocs.dm`):
  groups whose factions the same player leads, and groups staff marked as one
  bloc, share the 3-per-land cap, and a bloc never holds more than half of a
  land's provinces (`province_cap_refusal`).
- Admin > Province Blocs marks or clears a bloc, freezes or unfreezes a side's
  claims, and releases a held province. Each action needs a reason and is
  logged (`log_admin`, `message_admins`).

## Records

All under the account's ckey in shared player records:

| Kind | Body | Id |
| --- | --- | --- |
| `character_slot` | `slot`, `points` | `md5("character_slot\|ckey\|slot")`, so a copy from another region pays once |
| `character_switch` | `slot`, `from` | random; the latest (by `at`, a unix digit string) is the slot played |
| `character_named` | `slot`, `name` | random for each change; written when a Persistence character starts, and refreshed by the minute tick if the name changes |

New Persistence characters must have a different name from the other unlocked
slots on the same account. Case and spacing do not make a name different.
Existing characters can still be reclaimed and are not renamed. A local living
body supplies its current name; for a character in another land the check
uses the latest shared name record. Records still propagate asynchronously
and older remote bodies may not yet have a name record.

Hosts: the launcher's Player records lookup (`shard_group.py records --ckey`)
starts with the account's points and slots, and `shard_group.py accounts
--ckey K` answers them alone (`tools/transfer_storage/records.py`
`account_summary`, read-only).

Staff: Admin > Player Accolades shows the slots, points spent and names, and
"Lock slot" revokes a `character_slot` record with a reason. The character
stays asleep and the points stay spent.

## Owner keys

Every durable body, bed, home claim, travel record, event stash and death
legacy is kept under an **owner key**:

| Slot | Owner key | Example |
| --- | --- | --- |
| 1 | the account itself | `alice` |
| 2 to 4 | `@<slot><account>` | `@2alice` |

Slot 1 is exactly what was saved before slots, so nothing moves. No ckey,
account key or agent account starts with `@`, so a slot key never names
another account. The coordinator accepts slot keys up to 34 characters.

- `owner_key_for(account, slot)`, `owner_key_slot(key)` (0 when invalid) and
  `owner_key_account(key)` are in `code/modules/persistence/player_reclaim.dm`.
- `client.owner_key()` is the key of the slot the client plays now
  (`client.character_slot`, always 1 until the Characters window exists).
- `persistence_owner_valid` takes a slot key when its account is valid.

## Character or person

Use the owner key for anything that belongs to one character: the body, its
bed and home, faction membership (`faction_roster_account`), recruitment,
party trains, travel and death legacy.

Use `owner_key_account(key)` for anything that belongs to the person: accolades
and lifetime points, karma, the magic whitelist, player activity, admin
lookups and nation actors. Staff tools that take a ckey still find the
character being played.
