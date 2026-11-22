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

| Capstone | Bill |
| --- | --- |
| Steam Power | 60 coal, 40 iron, 10 copper |
| Powered Flight | 120 steel, 40 rubber, 30 brass, 40 cloth |
| Mechanized Warfare | 200 steel, 40 rubber, 40 lead, 30 sulphur, 30 saltpeter |

Sizes are starting values to tune from play. Electricity, Nuclear Power and the
Digital capstones are planned next; see the design doc linked from the PR.
