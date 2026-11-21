# Armor families

`python3 tests/armor_families/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled and checks, on a 6x4x1 world:

- The worked examples from the armor rework plan: linothorax, leather armor,
  leather samurai armor, bronze lamellar, chainmail and plated armor give the
  planned cut, pierce, blunt and arrow values, melee is the mean of the three
  melee kinds, and gun and bomb values stay the piece's own.
- Each family's matchup: mail turns cuts better than blows, padding blows
  better than thrusts, lamellar arrows better than mail of the same metal.
- Every look within a family and tier (samurai, varangian, chinese, roman and
  so on) has the same values and weight.
- A worn family piece protects its wearer by kind; armor without a family
  keeps reading its own armor list.
- A padded jack gives blunt and half arrow only; worn under mail it adds to
  the mail, and plate over mail closes the gaps a thrust finds.
- Forging sets the tier from the metal (iron plate cut 72, steel plate 85),
  and a stock grade lifts values up to 90 without lowering any.
- Armor never goes out of date: plated and samurai lord armor stay on offer
  from the Medieval age to the Digital age, iron and steel anvils keep their
  armor categories, and every armor and helmet anvil row is open-ended.

Negative controls restore one old behavior each and must fail:
`--negative-control no-family`, `no-forge-tier` and `era-closed`.

See `docs/armor-families.md`.
