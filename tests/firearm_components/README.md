# Modular rifle parts (AK, AR, Mauser, Mosin and Arisaka families)

`python3 tests/firearm_components/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled and, on a 6x4x1 world with a real
human:

- builds an AK-74's preset parts lazily (none until first use, once only);
- strips the magazine well by hand, refuses the barrel without a firearm bench
  (creating nothing), then removes it at a bench;
- converts the rifle to 7.62x39mm: a 7.62 barrel with the old 5.45 magazine well
  cannot fire, the matching 7.62 well makes it fire and load AKM magazines;
- refuses work on a loaded rifle, parts in a filled slot, parts on a non-modular
  gun, and a second install of an already-installed part;
- removing the stock lowers handling and reapplying parts never compounds it;
- 1000 shots of barrel wear block firing, and the worn barrel keeps its
  condition when removed and reinstalled;
- Save_World, ClearMap and Load_World keep the converted rifle's parts, wear,
  caliber and handling, give an untouched AKM (saved without parts) its preset
  once, and keep a loose part's id and condition with no duplicated parts.
- the real factory recipe list makes every part type and the bare receiver,
  all gated by Automatic Weapons, and a receiver built from fresh parts fires
  as a 7.62 rifle named "AK rifle (7.62x39mm)".
- an M4 builds the AR carbine preset (collapsible stock, x0.95 handling) and
  takes M16 and AR-15 magazines; its magazine well comes off by hand and AK
  parts are refused as a different family; the Service Rifle stays fixed;
- the AK-102 and AK-105 build 5.56 and 5.45 AK presets;
- a bare AR receiver built from factory parts fires as "AR rifle (5.56x45mm)",
  and an AK receiver can be built as "AK rifle (5.56x45mm)".
- a Kar98k builds the 7.92 Mauser preset (Gewehr 98 clips), is rebarrelled
  to 7.65x53mm at a bench and then loads a 7.65x53 round and takes 7.65 clips;
  AK parts are refused; an M1893 builds the 7x57 preset; a bare Mauser receiver
  holds no rounds and builds into "Mauser rifle (7x57mm)". Mauser recipes are
  gated by Cartridge Firearms, AK and AR ones by Automatic Weapons.
- a Mosin 91/30 builds the Mosin preset and has the strip verb, while the
  Obrez and a pistol stay fixed without it; an Arisaka Type 38 spawns 6.5x50
  rounds, builds the 6.5 preset and converts to 7.7x58 with Type 99 clips;
  Mosin parts are refused on it; bare Mosin and Arisaka receivers build into
  working rifles; a restored rifle keeps the strip verb after load.
- the parts panel shows a ready rifle with remove links, removes and refits the
  magazine well, shows the block reason and carried parts, previews a 5.45
  well (would not fire), the 7.62 well (fires) and a folding stock (x0.95
  handling) without changing the gun, and refuses parts the user does not
  carry and unknown slots;
- salvage returns 1 steel for a full magazine well, 2 for a full barrel and
  nothing for a worn-out one, previews the loss, only previews on the first
  request, needs a firearm bench and drops the steel on confirm.

Negative controls must fail: `--negative-control no-conversion-check`,
`compound-handling`, `eager-preset`, `free-salvage` and `preview-mutates`.

Code: `code/modules/1713/gunsmithing/firearm_components.dm`. Contract:
`docs/firearm-component-contract.md`.
