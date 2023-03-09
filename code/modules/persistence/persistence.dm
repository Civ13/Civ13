/datum/admins/proc/persistent()
	set category = "Server"
	set desc = "Set the current round as Persistent."
	set name = "Persistence"

	if (map && !map.persistence)
		map.persistence = TRUE
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
		world << "<big><b>The current round is now a Persistent Round.</b></big>"
	else
		map.persistence = FALSE
		map.gamemode = "Normal (Auto-Research)"
		config.allow_vote_restart = TRUE
		world << "<big><b>The current round is no longer a Persistent Round.</b></big>"
	return

/datum/admins/proc/persistent_chad()
	set category = "Server"
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
		world << "<big><b>The current round is now a Persistent Chad Mode + Round.</b></big>"
	else
		map.perschadplus = FALSE
		map.chad_mode = FALSE
		map.chad_mode_plus = FALSE
		map.gamemode = "Resource-Based Research"
		config.allow_vote_restart = TRUE
		world << "<big><b>The current round is no longer a Persistent Chad Mode + Round.</b></big>"
	return