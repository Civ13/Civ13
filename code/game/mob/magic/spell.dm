//totally not basing this off of the language datum system.

/datum/spell
	var/name 		= "Generic Spell"
	var/desc   		= "A generic spell."
	var/icon 		= 'icons/obj/magicprojectiles.dmi'
	var/icon_state 	= "spell"
	var/make   		= "Projectile"		// Spell Type.
	var/circle 	= 0			  			// 10 Circles of magic exist, 10 being godlike and 1 being stuff like "Clean".


	var/effect  = list()				//What the spell does. Like go boom.


	var/time    = 1						// Time it takes to cast.
	var/cost   	= 10					// Mana Cost.


//Procs
/mob/proc/add_spell()


/mob/proc/remove_spell()


/mob/verb/check_spells()
	set name = "Check Known Spells"
	set desc = "Lists the spells you know."
	set category = "IC"

	if (isliving(src))
		var/mob/living/M = src
	else
		src << "<span class='warning'>This verb may only be used while alive.</span>"
	return

/mob/verb/cast_spell()
	set name = "Cast Spell"
	set desc = "Casts a spell."
	set category = "IC"

	if (isliving(src))
		var/mob/living/M = src
	else
		src << "<span class='warning'>This verb may only be used while alive.</span>"
	return


//Spell in hand.
/obj/item/spell

//Spell Projectile.
/obj/item/projectile/magic
	name = "magic spell"
	icon = 'icons/obj/magicprojectiles.dmi'
	icon_state = "spell"