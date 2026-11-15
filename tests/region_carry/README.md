# Region travel carry probe

`native_probe.py` is developer evidence, not a CI suite. It compiles a
temporary copy of `civ13.dme` with `native_probe.dm` appended, runs it once
headless and checks `result.json`:

- packaged food and drink, a bruise pack, a crowbar, a helmet and a full
  magazine can travel;
- a loaded gun, a sipped can, a bitten cracker, a bandage subtype, a backpack
  and a magazine with a foreign round cannot;
- a payload with an unloaded gun and a partly emptied magazine decodes, and
  overfull magazines or storage items are refused;
- the rebuilt character holds the same items, with the gun still unloaded and
  the magazine holding exactly the rounds that travelled;
- anything else travels whole (`item:` kind, `region_travel_generic.dm`): a
  named pelt coat keeps its name and colour, a leaf covering is worn again
  under it, a waterskin keeps its water, a paddle and a master book with its
  chapters come along, and a pack basket arrives holding bones, ore and a
  second basket with its own waterskin. A bag holding a creature, a grab and
  forged records (setting `loc`, a structure, an unknown reagent) are refused.
- a ship's deck carries more than items (`ship_crossing_cargo.dm`): a named,
  hurt goat comes back as it was, a dead hen stays dead, a large barrel keeps
  its water, a prop barrel packs, and a dressed body comes back dead, named
  and dressed. A deck record holding them passes its own check. An animal a
  player plays, a helm or vehicle as cargo, a barrel as a worn item, a barrel
  inside an item and a forged body are refused, as are admin and map
  structures (an engine, an animal spawner, a money printer, a dock) and a
  barrel holding more than 10000 units. A wreck rebuilt without its
  creatures (a failed crossing puts back the ones that waited) makes none,
  and a display case emptied before it is deleted leaves no copy behind.

```sh
source ~/byond-516.1688/byond/bin/byondsetup
python3 tests/region_carry/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir
```

Recipe knowledge uses wire version 2. Updated peers accept legacy v1 bodies
without setting their migration marker; older peers refuse v2 rather than
silently dropping learned nodes. The probe also checks text-ID knowledge and
manual reconstruction, invalid/duplicate/associative IDs, malformed markers,
invalid manual quantities, and refusal of unknown future versions.
