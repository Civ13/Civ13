/datum/mind
	var/list/learned_spells

//A fix for when a spell is created before a mob is created
/mob/Login()
	. = ..()
	if(mind)
		if(!mind.learned_spells)
			mind.learned_spells = list()

proc/restore_spells(var/mob/H)
	if(H.mind && H.mind.learned_spells)
		var/list/spells = list()
		for(var/spell/spell_to_remove in H.mind.learned_spells) //remove all the spells from other people.
			if(istype(spell_to_remove.holder,/mob))
				var/mob/M = spell_to_remove.holder
				spells += spell_to_remove
				M.remove_spell(spell_to_remove)

		for(var/spell/spell_to_add in spells)
			H.add_spell(spell_to_add)

/mob/proc/add_spell(var/spell/spell_to_add, var/spell_base = "wiz_spell_ready")
	spell_to_add.holder = src
	if(mind)
		if(!mind.learned_spells)
			mind.learned_spells = list()
		mind.learned_spells |= spell_to_add
	return 1

/mob/proc/remove_spell(var/spell/spell_to_remove)
	if(!spell_to_remove || !istype(spell_to_remove))
		return

	if(mind)
		mind.learned_spells -= spell_to_remove
	return 1
