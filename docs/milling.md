# Industrial milling

Source: `code/modules/1713/milling.dm` (hopper hook `hopper_accepts` and
`mill_stop_reason` in `stone_crushing.dm`). Node **Industrial Milling**
(Industrial, era 4, after Amalgamation and Steam Power).
Tests: `tests/milling/test_contract.py`, native probe `tests/milling/probe.dm`.
Art: `tests/sprites/create_milling.py` -> `icons/obj/milling.dmi`.

Every machine is a `/obj/structure/drill/stamp_mill/water` subtype: a turning
mover within reach drives it, it takes up to 50 units of feed in its hopper,
works one per cycle while it has feed, water and drive, and stops with a
reason when one runs out or its output tile fills. Factory ports feed the
hoppers as for the stamp mills.

| Machine | Cost | Feed | Cycle | Water | Result |
| --- | --- | --- | --- | --- | --- |
| Trommel | 12 iron | pay dirt | 4 s | 10 | washed in a free sluice beside it, at sluice rates, using its quicksilver |
| Amalgamator drum | 15 iron | crushed ore + quicksilver | 6 s | 15 | amalgam at 80%, amalgam tailings; loses 0.2u a load, 0.03u with a mercury separator (8 iron) beside it |
| Shaking table | 10 iron | crushed ore | 4 s | 10 | clean metal ore at 65%, tailings; no quicksilver |

**Amalgamation plates** (4 copper) fit any stamp mill (water or powered). Charged
with quicksilver, the mill turns lode ore straight into amalgam at 50% (0.05u
lost a load) plus amalgam tailings; without quicksilver it crushes as before.

Quicksilver lost goes through `river_mercury_spill` (amalgam.dm): river bed
beside water, ground pollution elsewhere.
