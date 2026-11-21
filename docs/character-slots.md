# Character slots

Part of the lifetime points plan (accolades are in `docs/accolades.md`). An
account may later unlock up to four characters. This page covers how they are
kept apart in saves; the Characters window, unlocking and switching come later.

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
