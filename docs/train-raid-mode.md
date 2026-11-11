# Train Raid: boarding, lift balloons, recall and the line collapse

Train Raid is a finite round in which two raiding crews dock their home
shuttle trains beside a long freight train, the Hauler, board it, loot its
tiered sections and get the loot back to their shuttle before the line
collapses. It borrows the general shape of modern train-raid games (board from
a home train, extract small loads early with balloons, recall the home train
for the full crew, a round that ends on a timer, lives and bed respawns) using
original Civ13 geometry, names and items. The mode is selected by name
(`train_raid`), like Factory and Crossroads Mall, and is never in a vote
rotation.

Naming: the earlier map studies call the home train the "Dagger", which is
also the commercial game's name for it. Source paths and the generator keep
`dagger` for continuity with those studies; everything players read calls it
the **shuttle**. Mid-raid extraction uses **lift balloons**; the round-end event
is the **line collapse**.

## Round flow

| Phase | What happens |
| --- | --- |
| Start | Both shuttles are docked at the west and east berths with their boarding bridges extended. Loot pads roll by section tier. Crews spawn in their shuttle bunks with a basic kit, two lift balloons and a shuttle beacon. |
| Boarding | Five minutes after the round starts (or earlier from the helm), each shuttle departs: its bridges retract into an impassable gap and the shuttle is away. Anyone still aboard rides with it until the next docking. |
| Raiding | Crews breach compartment doors rear to front. Sections nearer the locomotive hold better loot. Lift balloons send one item or crate at a time to the shuttle stores; the coaches, vault car and locomotive need a boarding pass loaded at the helm first. |
| Recall | A crew member on the train uses their shuttle beacon, burning 2 fuel. The shuttle takes three minutes to arrive, docks for a two-minute window, then departs again. Whoever is aboard, and everything in the shuttle, is secured. A departed shuttle can be recalled again after a five-minute cooldown. |
| Line collapse | Sixty minutes after the start, warnings at thirty, fifteen, five and one minutes. At zero every item still on the Hauler and the platforms is destroyed, every raider still there is lost, the two crews' secured value is announced, each shuttle's hold is saved for its party and the round ends. |

## Lives and respawns

- Every raider has three lives per round. Dying with lives left and a claimed
  bed returns the raider next to that bed with a fresh basic kit and nothing
  they were carrying. Click a bed on the Hauler or the shuttle to claim it;
  one bed per raider, one raider per bed, and a destroyed bed loses its claim.
- Out of lives, or without a claimed bed, the raider respawns in their
  shuttle's bunks with a basic kit. If the shuttle is away they wait for the
  next docking.
- Equipment left on the Hauler at the collapse is gone for good. What is
  aboard the shuttle is saved for its captain's party (see below); the
  secured value is the round score.

## Saved shuttles, fuel and boarding passes

A crew's shuttle belongs to a party and comes back round after round.

- **Ownership.** The first raider to join a crew in a round is its captain. The
  shuttle is the captain's party's (`ckey:<key>`, the same party ids as party
  trains); a key can captain only one crew per round. Later raiders of that
  crew sail on the captain's shuttle. A party with no save gets a new shuttle:
  6 fuel and one coaches pass in the stores.
- **Saved hold.** At the line collapse everything aboard the shuttle is packed
  with the party freight codec ([party-freight.md](party-freight.md)): loose
  items, crates, locker contents and what living crew aboard carry, most
  valuable first, up to 40 loads. A container holding something the codec
  cannot rebuild is emptied into its own loads first. Fuel cells aboard top up
  the tank (up to 20), boarding passes and lift balloons are kept as counts
  (up to 12 each), beacons are reissued with the kit, and anything else that
  cannot be rebuilt (some medical kits, for one) stays behind and is lost. When
  the captain joins next round the hold is unloaded into the stores.
- **Fuel.** A beacon recall burns 2 fuel. The check and the spend happen in
  one step, so a recall is never free or paid twice; a recall that is refused
  costs nothing and fuel is never refunded once the shuttle sets off. Load
  shuttle fuel cells (2 each) or coal (1 per piece) at the helm. Fuel cells
  turn up in the rear sections.
- **Boarding passes.** The brake van, flatcars and boxcars are open. A
  boarding pass for the crew coaches, vault car or locomotive, loaded at the
  helm, clears that section and every section behind it for lift balloons
  until the round ends; loading spends the pass. Doors never ask for one: a
  pass gates lifting cargo out, not walking in, and loot carried back aboard
  by hand is always kept. Passes for the next section forward turn up as loot.

Saves live in `data/train_raid_shuttles/<key>.<slot>.json`. Each save writes
the next generation into the older of two slots and reads it back, so a failed
write leaves the newer slot loading. If a party has saves but none can be read,
its crew sails a stand-in shuttle that round and nothing is written over the
damaged save. Only the line collapse saves: a round that ends any other way
keeps the previous save, so nothing is duplicated and that round's gains are
lost.

## Shuttle protection

The shuttle's rear rooms (bunks, stores, engine room, helm) are crew only.
Their airlock doors open only for the owning crew and cannot be damaged,
kicked, picked or deconstructed. The centre carriage and forward rooms are
open to boarding whenever the shuttle is docked. The helm offers `Depart now`
and shows the shuttle state; the engine mount is decorative.

## Map

`maps/EFT/train_raid.dmm` is generated by `tests/train_raid/build.py`, which
composes the Hauler raid station study with two copies of the four-level
shuttle study, one in each berth, and adds the mode objects: crew spawn
landmarks, store landmarks, helm consoles, bridge gates, crew doors, loot pads
on the section anchors and the map metadata object. Validators and the two
WIP studies are unchanged.

## Not in this version

NPC train guards, helm upgrades, sustenance recovery in the safe rooms and
rebuilding the shuttle's own furniture from the save (the hold is saved, the
shuttle's fixed fittings come from the map). The instance and reservation
contracts in [dagger-train-map.md](dagger-train-map.md) still describe a
shuttle that moves between worlds; this round-based mode keeps both shuttles
fixed to their berths and settles fuel and passes as described above.

## Files and verification

- `maps/EFT/train_raid.dmm` and `.layout.json`: generated; edit
  `tests/train_raid/build.py` and regenerate.
- `code/game/objects/map_metadata/train_raid.dm`: the mode, crews, jobs,
  bridge gates, helm, crew doors, beds, loot pads, lift balloon and beacon.
- `code/game/objects/map_metadata/train_raid_shuttle.dm`: saved shuttles,
  fuel, boarding passes and the two-slot save.
- `tests/train_raid/test_train_raid.py`: offline map and source checks, run
  by the `train_raid` CI suite.
- `tests/train_raid/native_probe.py` with `native_probe.dm`: a headless
  DreamDaemon round-flow probe (developer evidence, not CI).

```sh
python3 -I -B tests/train_raid/build.py --check
python3 -I -B tests/train_raid/test_train_raid.py
python3 tests/train_raid/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir
```

The offline suite checks both shuttles are docked in their berths, bridge
gates cover every bridge cell, crew doors sit on the airlock, spawn and store
landmarks are inside the crew rooms, every Hauler anchor has a loot pad with
tiers rising rear to front, no Hauler door is locked, and a walking route
exists from each shuttle's boarding ports to every section without passing a
crew door. The probe starts a round headless, spawns clientless raiders,
and checks the kit, the new shuttle's fuel and starter pass, crew-door
authorization, helm departure, beacon recall with cooldown, fuel and docking
window, a balloon refused without a pass and accepted with one, bed claims,
lives and bed respawn registration, the line collapse saving the hold, the
saved shuttle coming back for its captain, and a damaged save refusing to
load. Neither is real-client
acceptance: movement, lighting, combat and what players see are unverified.
