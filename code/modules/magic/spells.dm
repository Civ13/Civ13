//Spells go here.

/*
SPELL SCHOOLS:

These all follow the same naming sense. (-tion)

Abjuration - Wards, Buffs, Enchanting, that sorta thing.
Alteration - Manipulating stuff, like telekinesis.
Conjuration - Summoning.
Divination - Premonition, Oracle stuff.
Evocation - Typical Spell, Like fireball n such.
Restoration - Healing n such.
Transmutation - Changing one thing into another.

It bugs me this doesn't match the other school names.
May not use these.

Necromancy - Dealing with the dead. - Conjuration? Not really, Transmutation? Not really.
Illusion - Tricking Sense - Kinda like conjuration?

*/
/*
Potential SFX
sound/effects/bamf.ogg - Soft bamf noise

sound/effects/bang.ogg - loud bamf

sound/effects/cardboard_punch.ogg - thud noise

sound/effects/cascade.ogg - watery magic sound

sound/effects/custom_flare.ogg - hiss

*/
/datum/spell/clean
	name 		= "Cleanse"
	desc   		= "Cleans the target."
	icon_state 	= "cleanse"
	proj_state	= "energy2"
	school   	= "Restoration"
	circle 	= 1

	time    = 1
	cost   	= 10

/datum/spell/close_wounds
	name 		= "Close Wounds"
	desc   		= "Stops Bleeding."
	icon_state 	= "telekinesis"
	proj_state	= "energy2"
	school   	= "Restoration"
	circle 	= 1

	time    = 1
	cost   	= 10

/datum/spell/force_bolt
	name 		= "Force Bolt"
	desc   		= "A projectile of pure manna."
	icon_state 	= "telekinesis"
	proj_state	= "energy"
	school   	= "Evocation"
	circle 	= 1

	time    = 1
	cost   	= 10

/datum/spell/telekinesis
	name 		= "Telekinesis"
	desc   		= "Manipulate objects with manna."
	icon_state 	= "telekinesis"
	proj_state	= "energy"
	school   	= "Alteration"
	circle 	= 1

	time    = 1
	cost   	= 10