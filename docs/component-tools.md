# Component tools

Combine a pickaxe, shovel or hatchet head with a handle using the existing
head-on-handle interaction. Assembly stays immediate, with no timing game.
Existing head production, handle recipes and age/research requirements remain.
Spear, throwing axe and battleaxe assembly retain their existing behavior.

The existing wood handle costs one plank. A plank handle costs two planks and
70 ticks, offering a lighter, stronger grip. A reinforced handle costs two iron
ingots and 70 ticks with the same research threshold as a wrench; it gives
greater capacity but a heavier, slower grip. These use existing handle sprites.

The finished work tool records both materials, qualities and input conditions.
The head still supplies its native material damage, hardness and wear behavior.
Finished quality is the lower input quality, bounded to 0.5-2, so an excellent
handle cannot turn a crude head into an excellent tool. Existing force rules
apply this quality; no shared material datum is changed.

Handle integrity relative to ordinary wood adjusts capacity within 0.5-1.5
of the head's normal capacity. The worse input condition carries over, so using
a damaged handle does not restore a damaged head. Handle weight relative to
ordinary wood adjusts shovel/pickaxe work speed within 0.75-1.25 of its normal
speed. Head hardness relative to iron additionally adjusts pickaxe speed
within 0.5-1.5; final pickaxe speed stays within 1-3, the existing bone-to-steel
range. This changes existing work durations, not mineral output quantities.
Hatchet chopping delays retain their existing behavior because several tree
paths ignore the chopping_speed property.

Examine an assembled tool to see its component materials and qualities.
Existing tools and old saves without component records keep their current
stats. Existing quality is normally 1; this does not introduce randomized grades.
This first extension does not add repair, disassembly or new assets.

Design references: Pocket Stronghold's head-and-stick workbench recipes at
`2bfb1906a9a68f58c5e5da25383f83dd495bf138`, and DF13's separate head/handle
records at `64b47a2a62c374ca07e3c4c03ebc460ccad43553`. No code or assets were
copied from either project.
