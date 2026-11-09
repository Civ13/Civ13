# Lobbed arrows

`run.py --byond-bin <pinned-bin>` compiles the production sources without maps
or normal startup into a 16x6 plating world, writes a height file with one case
per row and runs `probe.dm` once with real arrows through `handleTurf`:

- A wall between archer and target stops a direct arrow; a lobbed arrow clears
  it and comes down on the target.
- A bystander under the arc is flown over and the aimed-at person is hit.
- A 3-level rise under a 10-tile lob is passed; a 10-level ridge in the middle
  stops it.
- A roofed landing tile takes the arrow on the roof; nobody under it is hit.
- The landing scatter grows with distance (mean offset at 3 and 13 tiles).
- A lob waits for its flight time between tiles.
- Bows toggle between direct and lobbed; crossbows cannot lob.

`--negative-control arc` (lobs fly like direct shots), `ridge` (no hillside
stop), `roof` (roofs ignored on landing) and `scatter` (no distance scatter)
change a generated copy; each must fail its named check. Evidence goes to a
fresh temporary directory. No client, save or live server.
