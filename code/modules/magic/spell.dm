open//totally not basing this off of the language datum system.


/datum/spell
	var/name 		= "Generic Spell"
	var/desc   		= "A generic spell."
	var/icon 		= 'icons/obj/magicprojectiles.dmi'
	var/icon_state 	= "energy"
	var/proj_icon	= 'icons/obj/magicicon.dmi'
	var/proj_state	= "0"

	var/school   	= "Abjuration"		// Spell Type.
	var/circle 		= 0			  		// 10 Circles of magic exist, 10 being godlike and 1 being stuff like "Clean".

	var/castsound 	= 'sound/effects/drop_wood.ogg'

	var/time    = 1						// Time it takes to cast.
	var/cost   	= 10					// Mana Cost.


//Procs

/mob/proc/add_spell(var/datum/spell/S)
	//So basically loop through spells, if it matches stop, else add the spell.
	if(spell_list.Find(S,1,0))
		src << "<span class='warning'>Spell not added; already known!</span>"
		return
	spell_list.Add(S)
	src << "<span class='warning'>Spell added successfully!</span>"
	return

/mob/proc/remove_spell(var/datum/spell/S)
	//So basically loop through spells, and if it matches rem the spell.
	for(var/datum/spell/SS in spell_list)
		if(SS == S)
			spell_list.Remove(SS)
			src << "<span class='warning'>Spell removed successfully!</span>"
			return
	src << "<span class='warning'>Spell not removed; spell unknown!</span>"
	return

/mob/proc/cast_spell(var/datum/spell/S)


//verbs
/mob/verb/check_spells()
	set name = "Spellcast"
	set desc = "Lists the spells you know for selection."
	set category = null
	set src = usr

	if (isliving(src))
		var/dat = "<b><font size = 5>Spells</font></b><br/><br/>"

		for (var/datum/spell/S in spell_list)
			dat += {"<a href='byond://?src=\ref[src];spell=[S]>
			<b>[S.name]</b> - <i>[S.school] [S.circle]</i><br/>[S.desc]<br/><br/>
			</a>"}

		if(spell_list.len > 0)
			src << browse(dat, "window=checklanguage")
		else
			src << "<span class='warning'>You know no spells!</span>"
	else
		src << "<span class='warning'>This verb may only be used while alive.</span>"
	return

//Spell in hand.
/obj/item/spell
	name = "magic spell"
	icon = 'icons/obj/magicprojectiles.dmi'
	icon_state = "spell"
	nothrow = TRUE
	var/datum/spell/SPEL = /datum/spell

/obj/item/spell/dropped()
	//create spell at location
	qdel(src)

/obj/item/spell/attack(atom/A, mob/living/user, def_zone)
	playsound(src.loc, SPEL.castsound, 80, TRUE)
	missile(src, user, A.loc)
	//shoot code
