# Matchlock and musket loading

`python3 tests/matchlock_loading/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled and checks the real gun types.

A player (2026-11-17) could not load cast musket balls or musket cartridges
into a matchlock musket, arquebus or tanegashima: those guns only accepted stone
shot. The probe checks that every matchlock-family gun turns a lead musket ball
into a musket-ball round (and still takes stone shot, but not pistol balls),
that a loaded gun fires a musket ball, and that a flintlock musket answers a
loose ball with a hint and refuses a pistol cartridge.

`--negative-control no-musket-ball` removes the lead-ball mapping and must fail.
