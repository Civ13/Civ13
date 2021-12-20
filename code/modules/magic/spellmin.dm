var/list/admin_verbs_magic = list(
	/client/proc/addrem_spells,
	/client/proc/list_spells
	)

/client/proc/list_spells()
	set name = "List Spells"
	set desc = "List all the spells."
	set category = "Admin"
	set src = usr

	if (!holder)	return
	if (!check_rights(R_ADMIN))
		return

	var/dat = "<b><font size = 5>Spells</font></b><hr>"
	for (var/datum/spell/S in all_spells)
		dat += "<b>[S.name]</b> - <i>[S.school] [S.circle]</i><br/>[S.desc]<br/><br/>"
	src << browse(dat, "window=checklanguage")
	return

/client/proc/addrem_spells()
	set name = "Add/Rem Spells"
	set desc = "Add or Remove spells from a mob."
	set category = "Admin"
	set src = usr

	if (!holder)	return
	if (!check_rights(R_ADMIN))
		return

	var/inp = WWinput(src, "Select target.", "Add/Rem Spells", WWinput_first_choice(human_mob_list), WWinput_list_or_null(human_mob_list))
	if(inp == "Cancel")
		return
	var/mob/living/human/target = inp

	inp = WWinput(src, "Do you want to add or remove a spell?", "Add/Rem Spells", "Cancel", list("Add","Remove","Cancel"))
	if (inp == "Add")
		inp = WWinput(src, "Which Spell?", "Add/Rem Spells", "Cancel", all_spells)
		if(inp == "Cancel")
			return
		var/datum/spell/spel = inp

		target.add_spell(spel)
	else if (inp == "Remove")
		inp = WWinput(src, "Which Spell?", "Add/Rem Spells", "Cancel", target.spell_list)
		if(inp == "Cancel")
			return
		var/datum/spell/spel = inp

		target.remove_spell(spel)
	else if (inp == "Cancel")
		return
	else
		return