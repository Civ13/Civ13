# Accolades

Lifetime points for an account. Code: `code/modules/accolades/accolades.dm`,
minute count `code/processes/accolades.dm`, tests `tests/accolades/`.

## Rules

- Each accolade can be claimed once per account, ever. Meeting it marks it
  ready; the player presses Claim in the **Accolades** window (OOC tab).
- Points are kept for good. Later they unlock extra character slots; nothing
  else spends them and they never trade.
- Earned only in persistent lands. The TDM barracks and battle worlds, event
  lands, raid lands and the tutorial region earn nothing, except First Steps,
  which is finished in the tutorial. A world outside a shard group earns when
  it keeps characters.
- Guests and host agents never earn. A Discord account key earns as the ckey
  verified for it.
- Time counts only while the character is played, alive and awake (the same
  rule as staff playtime).

## Storage

Records in the shared player records store
(`code/modules/admin/shared_player_records.dm`), so every region of a group
sees the same accolades:

| Kind | Body | Id |
| --- | --- | --- |
| `accolade_met` | `accolade`, `land` | md5 of kind, ckey and accolade |
| `accolade` | `accolade`, `points` (`grant`, `reason` for staff grants) | md5 of kind, ckey and accolade; staff grants get fresh ids |
| `accolade_land` | `land` | md5 of kind, ckey and land |

Ids made from the ckey mean two regions writing the same claim store it once,
and a claim staff revoked cannot be claimed again.

Per-character counters (`accolade_progress`: minutes, seasons, faction and
minutes in it) are saved with the body and carried on trips (`P["accolades"]`).

## The first list

| Accolade | Condition | Points |
| --- | --- | --- |
| First Steps | Finish the tutorial | 5 |
| Settled | Sleep in a bed assigned to you | 5 |
| Survivor | One character alive 10 hours of play | 15 |
| Old Hand | One character alive 50 hours of play | 40 |
| Four Seasons | One character lives through every season of a year | 20 |
| Apprentice | One character knows 10 research subjects | 10 |
| Scholar | One character knows 50 research subjects | 30 |
| Pioneer | Be in the faction whose research moves the land into a new era (played members present share it) | 30 |
| Sailor | Set out on a voyage from a tiller | 10 |
| Wanderer | Live in 3 different lands | 15 |
| World Traveller | Live in every surface land of the group | 40 |
| Citizen | 10 hours of play in one faction | 10 |

No accolade rewards killing players, dying or anything hidden.

## Staff

Admin > **Player Accolades** (`code/modules/admin/accolades_admin.dm`): see an account's accolades, points and lands;
grant an accolade (fresh record, with a reason) or remove a claim (revokes it,
with a reason). Removing a claim never takes away a slot already unlocked.
