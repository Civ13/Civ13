# Modular rifle parts (AK pilot)

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

Negative controls must fail: `--negative-control no-conversion-check`,
`compound-handling` and `eager-preset`.

Code: `code/modules/1713/gunsmithing/firearm_components.dm`. Contract:
`docs/firearm-component-contract.md`.
