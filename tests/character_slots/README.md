# Character slots

Offline source checks, run by the `character_slots` suite in `scripts/ci_baseline.py`:

    python3 -m unittest discover -s tests/character_slots

- Bodies, beds, homes, travel, event stashes and death legacy belong to the
  owner key (`client.owner_key()`): the account for slot 1, `@<slot><account>`
  for slots 2 to 4.
- Accolades, karma, magic, activity and admin lookups belong to the person,
  the account behind the key (`owner_key_account()`).
- The coordinator accepts slot keys, two characters longer than a ckey.

The owner key helpers run on the pinned engine in the accolades probe
(`tests/accolades/README.md`).
