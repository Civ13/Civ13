# Faction seals

Code: `code/modules/paperwork/faction_seals.dm` (stamping in `stamps.dm`). Tests:
`python3 tests/faction_seals/test_source.py`; native probe
`python3 tests/ecology_spawning/run_linux.py . tests/faction_seals/probe.dm`.

First step of the bureaucracy and currency plan: later offices, mints, treasuries, deeds,
warrants and notes can carry faction seal impressions. An impression does not
authenticate the contents of a sheet.

## Seal matrix

`/obj/item/weapon/stamp/faction_seal` (1 softwood, paper & printing, gated on Papermaking).
Uncut, it works like a plain wax seal and leaves no record.

- A faction leader (or an officer with the seals power, see `docs/faction-offices.md`) uses an uncut matrix in hand to **cut** it as a seal of their faction and
  names the office it speaks for (Leader, Treasurer, Registrar, ... up to 32 letters).
  It becomes "seal of FACTION (OFFICE)", seal no. N.
- A faction keeps at most 24 seals in force.
- The same people, holding any matrix, can **list** the faction's seals and **revoke** one. A
  revoked seal still presses an impression, but it checks as void.
- Anyone holding a cut seal can use it. A stolen seal works until it is revoked; that is the
  game.

## On the paper

Pressing a cut seal draws the court seal impression like any stamp and adds a
`seal_records` entry `faction|office|serial|realtime|seal clock` to the paper (plain text,
saved with the paper, at most 12).

**Check Seals** (Object verb, held paper or paper on an adjacent floor tile) lists:

- signature text through the same language and literacy checks as the document reader. A
  signature mark does not verify the writer's identity, and copies can preserve it;
- each seal record as **matching the current register**, **void** (pressed after its revocation), **does not match**
  (the register lists that seal number for another office) or **unknown** (the faction keeps
  no such seal);
- how many other impressions carry no record: an ordinary stamp, a printed copy or a forgery.
  Printed copies reproduce the picture but never the record. A genuine impression does
  not prove the current text was present or approved when the seal was pressed.

## Register

`map.faction_recruitment["seals"]`: faction -> serial -> `list(office, cut realtime, revoked
seal clock or 0, revoked realtime or 0)`. `world.realtime` is a 32-bit float, good to about a
minute, so it is for display only. Ordering between impressions and revocations uses the
integer `map.faction_recruitment["seal_clock"]`, which ticks on each impression and
revocation. The register follows faction renames (`faction_roster_rename`) and is normalized
with the rosters. Existing impressions store the original name, so historical
verification across renames or name reuse is not reliable. Cutting and revoking
are logged with `log_game`.

Nothing here pays or buys anything, and no office is forced on anyone.
