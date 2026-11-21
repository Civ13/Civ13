# Character slots

Offline source checks, run by the `character_slots` suite in `scripts/ci_baseline.py`:

    python3 -m unittest discover -s tests/character_slots

- Bodies, beds, homes, travel, event stashes and death legacy belong to the
  owner key (`client.owner_key()`): the account for slot 1, `@<slot><account>`
  for slots 2 to 4.
- Accolades, karma, magic, activity and admin lookups belong to the person,
  the account behind the key (`owner_key_account()`).
- The coordinator accepts slot keys, two characters longer than a ckey.
- Slots 2 to 4 cost 100, 200 and 300 points, bought once with a shared id;
  only Discord-verified accounts unlock or play them, and a lobby login falls
  back to slot 1 without verification.
- Switching needs the character asleep in their own bed (or 30 minutes idle),
  no restraints, warrant, jail or recent hurt; a slot left waits an hour.
- The window keeps the structuring sentence word for word; staff can lock a slot.

The owner key helpers, buying, the hour wait and kin names run on the pinned engine in the accolades probe
(`tests/accolades/README.md`).
