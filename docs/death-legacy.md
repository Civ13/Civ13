# Keeping knowledge after a death

Gameplay balance; code in `code/modules/research_tree/death_legacy.dm`.

Death still clears everything a character knew. A record of it is kept with
the world for one real day, per account. The account's next character takes
the record back when it starts within 150 tiles of the death in one of two
ways:

- beside its faction's recruitment station (the member start), or
- at the account's own bed, if the bed had been theirs for a day before the
  death. A bed claimed after the death never counts and a destroyed bed ends
  the cover. Beds assigned before this was recorded count as long held.

Any other start, a start in another land, or a start after the day has passed
begins with nothing, as before. The lobby's starting place question says what
each choice keeps.

A bed only partly protects (Val, 2026-11-18): a start at the bed loses
double what the table below says, as if it were one more return. A start
beside a working recruitment station of the character's faction costs the
table's amount. On a continent, stations work only in provinces the
faction's side holds (docs/provinces.md), so holding land is the full
protection.

## What a return costs

| Cause | Lost |
| --- | --- |
| Starved, thirst, cold, heat, illness, poison | A fifth of what each body skill had gained |
| Wounds, an animal, a fall, anything else | A tenth of what each body skill had gained |
| Drowned or suffocated | A fifth of scholarship |
| Burned | A fifth of what crafting and dexterity had gained |
| Killed by another player | The three subjects learned last and a fifth of scholarship |
| Body destroyed, or died by their own hand | Everything |

A second return within a day of the first costs double, a third four times,
and so on. Body skills are never lowered below the starting level of 100.

## Weakness

After any death the account's next character in the same land deals half
damage to people for 30 minutes of play, melee, unarmed and ranged. Animals
and structures are not affected. The time counts only while the player is
connected and awake, and the Status tab shows what is left.

## Saving

`round.json` carries the records under `death_legacy`
(`valid_death_legacy_record` in `persistence/functions.dm`). Times are whole
real hours. Records are per world, so neither the knowledge nor the weakness
follows an account to another land.
