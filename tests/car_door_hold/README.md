# Car doors by hand

`python3 tests/car_door_hold/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 12x12 world with
real humans and a vehicle frame, checks
`code/modules/1713/machinery/modular_vehicles/vehicle_door_hold.dm`:

- a shut door with a lock starts locked and does not open from outside by
  hand; from inside, the release opens it, and the key locks it again;
- the key unlocks and opens it, a hand shuts it without locking, and an
  unlocked door pulls open from outside;
- grab intent inside shuts the door and puts the hold in the hand; using it in
  hand tightens the grip, and a tight, braced hold resists harder;
- each yank held off tires the holder, and a yank eventually tears the door
  open and frees the holder's hand;
- leaving the car, dropping the hold and a blow to the hand all let go;
- the "Hold Car Door" verb takes hold and lets go;
- the key locks a shut unlocked door in place; lockless doors never lock;
- only a tank has an escape hatch; it does not open from outside or while
  she moves, drops a crewman onto clear ground beside her, and refuses when
  there is none (`vehicle_exits.dm`);
- ships keep their own hatches;
- no runtime errors.

Random outcomes are retried until they happen. It needs the pinned compiler
(`bash scripts/cloud_byond_setup.sh`).
