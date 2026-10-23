/datum/admins/proc/persistent()
	set category = "Nomads"
	set desc = "Set the current round as Persistent."
	set name = "Persistence"

	if (map && !map.persistence)
		map.persistence = TRUE
		map.apply_persistence_age_floor()
		map.research_active = FALSE
		if (!map.autoresearch)
			map.autoresearch = TRUE
			spawn(100)
				map.autoresearch_proc()
		map.autoresearch_mult = 0.006
		if (map.default_research < 19)
			map.default_research = 19
		map.gamemode = "Persistent (Auto-Research)"
		config.allow_vote_restart = FALSE
		to_chat(world, "<big><b>The current round is now a Persistent Round.</b></big>")
	else
		map.persistence = FALSE
		map.gamemode = "Normal (Auto-Research)"
		config.allow_vote_restart = TRUE
		to_chat(world, "<big><b>The current round is no longer a Persistent Round.</b></big>")
	return

// age is the displayed epoch/date, not ordinal_age's technology tier. Only
// recognized BC epochs and canonical numeric years can be ordered here.
/obj/map_metadata/proc/apply_persistence_age_floor()
	if (!persistence)
		return
	if (age != "5000 B.C." && age != "313 B.C.")
		if (!istext(age))
			return
		var/year = text2num(age)
		if (isnull(year) || "[year]" != age || year >= 1943)
			return
	age = "1943"
	// Keep any independently advanced research tier. Mark the skipped epochs
	// complete so legacy research cannot send the displayed date backward.
	ordinal_age = max(ordinal_age, 6)
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE

/datum/admins/proc/persistent_chad()
	set category = "Nomads"
	set desc = "Set the current round as persistent Chad Mode +."
	set name = "Persistence Chad Mode +"

	if (map && !map.perschadplus)
		map.perschadplus = TRUE
//		map.persistence = TRUE
		map.research_active = FALSE
		map.autoresearch = FALSE
		map.chad_mode = TRUE
		map.chad_mode_plus = TRUE
		map.resourceresearch = TRUE
		map.default_research = 0
		map.gamemode = "Persistent Chad Mode +"
		config.allow_vote_restart = FALSE
		to_chat(world, "<big><b>The current round is now a Persistent Chad Mode + Round.</b></big>")
	else
		map.perschadplus = FALSE
		map.chad_mode = FALSE
		map.chad_mode_plus = FALSE
		map.gamemode = "Resource-Based Research"
		config.allow_vote_restart = TRUE
		to_chat(world, "<big><b>The current round is no longer a Persistent Chad Mode + Round.</b></big>")
	return
