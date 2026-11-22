# Era bills

On book-research worlds the late era capstones need a bill of materials as well
as their study and their demonstration or prototype (Val, 2026-11-22). Code:
`code/modules/research_tree/era_bills.dm`. Tests: `tests/late_research`
(`late_test_era_bills` in the native fixture, `EraBills` offline).

Val's rules: multiple factions are never a hard requirement. Anyone can do every
part. Sourcing the materials and the skills is the hard part, and factions
specialise through what their region makes easy (continent resources, rich
provinces, jungle-only rubber), never because a rule forces it.

- With the capstone's book on a bench working on it, use a stack of a listed
  material on the bench. The bench takes only what is still owed and writes it
  into the book (`research_bills`, `node=key:amount,...;...`). No faction,
  membership or knowledge check applies to delivering.
- Deliveries travel with the book. Copying or printing never copies them, and a
  destroyed book loses them.
- A capstone without a demonstration (Powered Flight, Mechanized Warfare) takes
  its bill in place of its old bench prototype (small fuel tank, tank casing).
- Writing a lost capstone again from memory (era_loss.dm) needs no bill.

| Subject | Bill |
| --- | --- |
| Steam Power | 60 coal, 40 iron, 10 copper |
| Electricity | 80 copper, 30 zinc, 20 lead, 20 rubber |
| Powered Flight | 120 steel, 40 rubber, 30 brass, 40 cloth |
| Mechanized Warfare | 200 steel, 40 rubber, 40 lead, 30 sulphur, 30 saltpeter |
| Nuclear Power | 30 uranium ore, 120 lead, 150 steel, 100 concrete |
| Digital Computing | 250 copper, 100 aluminium, 60 gold, 60 silver, 60 electronics, 15 gems |
| Digital Networks | 350 copper, 150 aluminium, 80 gold, 80 silver, 100 electronics, 25 gems |
| Automatic Weapons | 60 steel, 30 lead, 20 brass |
| Aviation & Rocketry | 80 steel, 30 aluminium, 20 rubber |
| Missiles | 60 steel, 40 sulphur, 40 saltpeter |
| Composite Armour | 100 steel, 60 aluminium, 20 rubber |
| Rocketry | 100 aluminium, 80 steel, 40 sulphur, 40 copper |
| Orbital Flight | 200 aluminium, 40 gold, 30 silver, 60 electronics |

Every era capstone from Steam Power on has a bill, and so do the biggest late
subjects, so finishing an era is hard and not only entering it. A bill material
comes from a subject of an earlier era (or its own groundwork), so no bill needs
the chapter it pays for. Sizes are starting values to tune from play.
