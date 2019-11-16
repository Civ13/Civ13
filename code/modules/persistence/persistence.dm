/datum/admins/proc/persistent()
	set category = "Server"
	set desc="Set the current round as persistent"
	set name="Persistence"

	if (map)
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
	world << "<big><b>The current round has been set as a Persistent Round.</b></big>"
	return