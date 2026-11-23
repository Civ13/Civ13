# Levers & Mechanisms

A lever, pull cord, pressure plate or tripwire can be tied with rope to the doors, gates and bells around it, so that working it opens, shuts or rings them from a distance. Hang a rock drop over a doorway and a stranger stepping on your plate gets a load of stones on their head. All of it can be built from the first age on.

| Part | Made from | Research | What it does |
| --- | --- | --- | --- |
| <img src="../images/Lever.png"> Lever | 3 wood | Basic Toolmaking | Throw it to open what it is tied to; throw it back to shut it again |
| <img src="../images/Pull_cord.png"> Pull cord | 1 rope | Basic Toolmaking | Each pull opens what is shut and shuts what is open |
| <img src="../images/Pressure_plate.png"> Pressure plate | 3 stone | Field Defenses | Gives one pull when a stranger or a large animal steps on it |
| Tripwire alarm | 2 tin | Basic Toolmaking | Rattles, and gives one pull, when a stranger walks through |
| <img src="../images/Rock_drop.png"> Rock drop | 6 stone | Field Defenses | Drops stones on whoever stands under it when pulled |
| <img src="../images/Pulley_block.png"> Pulley block | 3 wood | Resource Processing | Lets the cords of a trigger beside it reach one level up or down |

## Tying cords

1. Build the lever or pull cord, or set the pressure plate or tripwire.
2. Hold **rope** and click the lever, cord, plate or tripwire. A list shows everything within 7 tiles on the same level that a cord can work, and on the levels above and below if a pulley block stands beside the trigger.
3. Pick one. Each cord uses one rope, and up to 4 cords can be tied to one trigger.

A cord can work:

* doors, windows, shutters and trapdoors (not doors with keypads, key slots or faction locks);
* castle drop trapdoors;
* gate winches, which raise or drop their portcullis or drawbridge at once;
* bells, which ring an alarm;
* rock drops;
* shaft clutches, which a lever throws in and out, and counterweight drums, whose brake a lever sets and lets off (see [Mechanical power](Guide_to_Pottery_and_Lime.md#mechanical-power)).
* the hopper gates of millstones, sash saws, fulling stocks and bark stamps: a lever thrown over opens the gate and thrown back shuts it (see [Hopper machines](Guide_to_Pottery_and_Lime.md#hopper-machines));
* [sluice gates](Guide_to_Floods.md) in a levee: a lever thrown over draws the boards up and thrown back lowers them;
* relays and mechanism ports (below).

To take a cord off, use rope on the trigger again and pick **Cut the cord**; you get the rope back. Examine a trigger to see where its cords run.

## Working them

* A **lever** stays where you put it. Thrown over, it opens doors, drops trapdoors and raises gates, rings bells and lets rock drops go. Thrown back, it shuts the doors and trapdoors and drops the gates again.
* A **pull cord** gives one pull. Each door or gate it is tied to swaps between open and shut. A plate or tripwire works the same way.
* A door that is barred, locked or held shut by someone stays shut. A trapdoor never opens under someone standing on it; build a castle drop trapdoor for that.
* A pull cord or plate needs a couple of seconds before it can pull again.

## Pressure plates

Hold the pressure plate and use it in your hand to set it into the ground where you stand. The plate remembers who set it: you and your own people (your civilization, or your side on a battle map) can walk over it safely. Anyone else, and any medium or large animal, sets it off.

Click a set plate with an empty hand to prise it back up. Any cords on it come back as rope.

## Rock drops

A rock drop is a net of stones hung from a frame over one tile. When a cord pulls it, the stones fall on everyone standing there, hurting and knocking them down. Armour helps. Click an emptied rock drop with an empty hand to haul the stones back up.

## Pulley blocks

Build a pulley block within one tile of a lever, pull cord, plate, tripwire or clock. The rope list then also shows doors, bells, gates and rock drops within 7 tiles on the level directly above or below, marked "one level up" or "one level down". Those cords only work while the pulley block stays in place; take it away and they hang slack until it is put back.

## Clock alarms

A water clock or a tower clock can work cords too, so a bell rings or a gate opens at a set time.

1. Use rope on the clock to tie cords, the same way as on a lever.
2. Use the clock's **Set Alarm** verb and pick an hour.

A water clock gives one pull when that hour begins, as long as it holds water. A tower clock pulls when it strikes, as long as it is wound, and can also be set to pull every hour.

## Cam drums

<img src="../images/Cam_drum.png"> A cam drum (6 wood, 1 gear set, 1 shaft, Watermills) is a pegged barrel that pulls its cords one after another while a treadwheel, horse gin, mill wheel, windmill, counterweight drum or line shaft turns it. Tie cords to it with rope as you would to a lever, then click it with an empty hand to set it running or stop it. Behind a horse gin it pulls a cord about every 10 seconds; a faster drive pulls sooner. Use it to ring a set of bells in turn, or to open and shut doors on a cycle.

## Relays

<img src="../images/Relay.png"> A relay (3 copper, Electricity) is a copper knife switch for an electric lamp, outlet or other device on a cable. Set it on the same tile as the device. While the relay is open the device has no power, and once it is closed again the device draws power as before. Throw it by hand, or tie a cord to it: a lever thrown over closes it, a lever thrown back opens it, and a pull cord or pressure plate flips it. A pressure plate at a door can light the lamps inside, for example.

## Mechanism ports

A mechanism port (5 electronics, Digital Computing) joins the cords to an [integrated circuit](Guide_to_Integrated_Circuits.md). Set it on the floor, put a circuit inside it, and use rope on it to tie cords as you would on a lever. A signal on its **Pull** input pulls those cords, at most once every two seconds. A lever's or pressure plate's cord tied to the port sends a signal out of its **Pulled** output. Picking the port up drops its cords.

## Planning a contraption on paper

A ship's draught can hold a drawing of a contraption, so you can check its cords before you build it. Hold a blank draught (see [Guide to Boats](Guide_to_Boats.md#ships-draughts)) with a pen or pencil in your other hand, use it and choose **Draw a contraption on the sheet**.

- Pick a part and click a tile on the 12 by 12 plan. Choose **Tie cord**, then a trigger and the thing it works, to draw a cord. The plan checks that each cord is within reach and that no trigger has more than four cords. A portcullis must be within two tiles of its winch, and its cord goes to the winch.
- **Test pull or throw over** on a trigger, or **Test throwing back** on a lever, lists what would happen. Nothing in the world moves, rings or opens.
- The examples show a pressure plate ringing a doorway bell, a lever working a portcullis winch, and a lever working a sluice gate.
- **Save on this sheet** keeps the drawing, and the sheet's export and import share it as a code starting `C13MECH`. Build the real parts and tie the cords as described above.

