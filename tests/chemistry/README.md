# Polyethylene regression probe

Run `./tests/chemistry/run.ps1 -ByondBin 'C:\Program Files (x86)\BYOND\bin'`.
The runner compiles the production sources with normal world startup replaced,
then runs the real reagent holders and chemical reactions in temporary storage.
It does not start game schedulers, a client, or configured live-service adapters.

Checks cover elemental precursor recipes, polyethylene yield, missing catalysts,
catalyst retention, and rejection of propylene as polyethylene feedstock.
Logs remain in the printed temporary directory; generated build files are removed.
This is an isolated chemistry runtime check, not graphical gameplay acceptance.

For gameplay replication, use an isolated game and a reagent container with
adequate capacity. Mix 2 units of ethylene with 10 titaniumchloride,
5 borontrifluoride, and 5 aluminumchloride. Expect 25 polyethylene and unchanged
catalyst amounts. Omit a catalyst to verify no polymerization; substitute
propylene for ethylene to verify that it does not produce polyethylene.
