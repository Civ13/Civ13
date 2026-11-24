# Player Houses

In a persistent Nomads or Civilizations region, use **Faction → House → Player
Houses**. A character without a house can register a local charter. A steward
can invite nearby living characters as members or co-stewards. Invitations
require the character's explicit acceptance. Appoint a co-steward before you
need succession: a steward's death ends that life's authority, even after
revival, and does not dissolve the charter. If no steward can act, an administrator can use **Recover Player House** on
the existing charter after verifying the intended successor. The successor
must accept, and staff must record a reason. This changes only stewardship.

A surname, faction, or another character slot on the same BYOND account does
not grant membership. Houses are regional, not synchronized or travelled as
a group. Historical saves get an empty charter registry. The first draft
does not attach companies, migrate stock, restore any prior estate, or alter
profits or faction permissions.

The durable world schema writes v8 and reads v1–v8. Keep the last v7
generation when rolling back a v8 writer to an older server build. The house
registry contains plain text names, IDs, and role mappings, not mob references.
