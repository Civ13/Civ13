# Skull Island grace-end transfer

`test_grace_transfer.py` runs the production `/obj/map_metadata/skullisland/tick`
body through the shared source adapter. The parent tick, world teleporter list and
round clock are inert boundaries. It checks that the ship teleporters stay idle
during grace and activate exactly once when grace ends, whether by the timer or
an admin ending all grace periods.

Run with `python3 -B -m unittest tests.skullisland_grace.test_grace_transfer -v`.
Native map loading and the 20-tick teleport delay are not exercised.
