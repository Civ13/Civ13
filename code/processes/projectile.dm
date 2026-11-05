/process/projectile

/process/projectile/setup()
	name = "projectile movement"
	schedule_interval = 0.03 SECONDS
	start_delay = 1 SECOND
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_VERY_HIGH
	processes.projectile = src

/process/projectile/fire()

	for (current in current_list)

		var/obj/item/projectile/P = current

		// projectiles will qdel() and remove themselves from projectile_list automatically
		if (!isDeleted(P))
			if (P.loc)
				try
					P.process()
				catch (var/exception/e)
					catchException(e, P)
					log_debug("Hey a bullet just froze!")
					qdel(P)
		else
			catchBadType(P)
			projectile_list -= P

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

// Hard safety bound on projectiles in flight. Above it the oldest (launched
// first, furthest along) are dropped; the old 500 cap dropped the newest, so a
// big volley lost shots before they moved (100 of 600 in the projectile probe).
#define PROJECTILE_FLIGHT_CAP 1000

/process/projectile/reset_current_list()
	PROCESS_USE_FASTEST_LIST(projectile_list)
	var/excess = current_list.len - PROJECTILE_FLIGHT_CAP
	if (excess > 0)
		var/list/dropped = current_list.Copy(1, excess + 1)
		current_list.Cut(1, excess + 1)
		for (var/obj/item/projectile/P in dropped)
			qdel(P)

#undef PROJECTILE_FLIGHT_CAP

/process/projectile/statProcess(client/C)
	..(C)
	C.add_stat("[projectile_list.len] projectiles")

/process/projectile/htmlProcess()
	return ..() + "[projectile_list.len] projectiles"
