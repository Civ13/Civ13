# Laws, courts and warrants

Code: `code/game/mob/groups/faction_justice.dm`. Tests: `python3 tests/faction_justice/test_source.py`;
native probe `python3 tests/ecology_spawning/run_linux.py . tests/faction_justice/probe.dm`.

Step 7 of the bureaucracy and currency plan. Factions write laws, hold trials and keep a court record.
The game enforces none of it beyond the cell timer: players do.

## Faction Justice verb

The verb is on the Faction tab.

- Every member can read the laws, the warrants, outlaws and fines, and the court record (the last 40
  rulings).
- The leader writes laws (up to 20, 160 letters each) and repeals them. Every online member is told.
- Anyone with the **justice** power (`docs/faction-offices.md`: the leader, an appointed Judge, or
  whoever carries a seal of such an office) can:
  - **Hold a trial.** The judge must stand beside a gavel block. They pick the accused from people
    within 5 tiles, then choose the charge (a law, or free text), the verdict and the sentence. The
    trial ends any warrant for the accused and writes a judgment paper, which the judge can seal.
  - **Issue a warrant** for someone in sight or already in the court's books. It prints a wanted
    poster.
  - **Pardon**, which clears a warrant, outlawry and fines.

Sentences:

- Fine: 1-500 silver, added to what the person owes, paid at the strongbox.
- Jail: 1-30 minutes, written in the judgment.
- Banishment.
- Outlawry.
- Warning.

The justice power can now set a door's Cell Timer, so jail is served by shutting the convict
behind a door.

Examining anyone shows whether some faction has a warrant out for them or has declared them an
outlaw. Anyone can pay a fine at the faction's strongbox ("Pay a fine from my hand"), including for
someone else.

The gavel block and gavel hammer are now craftable (1 wood each, paper & printing, Papermaking).

## Saved state

`map.faction_recruitment["justice"]`: faction -> laws, warrants, outlaws, fines, record.
Renamed through `faction_roster_rename()` and cleaned by `faction_roster_normalize()`.
