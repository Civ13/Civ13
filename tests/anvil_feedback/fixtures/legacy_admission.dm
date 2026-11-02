/proc/anvil_admission(user)
	var/mob/living/human/H = user
	if (H.getStatCoeff("crafting") < 1.7)
		to_chat(user, "You don't have the skills to use this.")
		return
	if (!map.civilizations && map.ID != MAP_TRIBES && map.ID != MAP_THREE_TRIBES && map.ID != MAP_FOUR_KINGDOMS && map.ID !=MAP_GULAG13 && (user.original_job_title != "Blacksmith" && user.original_job_title != "Pioneer Blacksmith" && user.original_job_title != "Town Blacksmith" && user.original_job_title != "Ferreiro" && user.original_job_title != "Ferrero" && user.original_job_title != "Grofsmid" && user.original_job_title != "Forgeron" && user.original_job_title != "British Blacksmith" && user.original_job_title != "Marooned Pirate Crew" && user.original_job_title != "Schmied"))
		to_chat(user, "You don't have the skills to use this. Ask a blacksmith.")
		return
	return TRUE
