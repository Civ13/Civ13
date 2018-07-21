var/datum/reinforcements/reinforcements_master = null


/proc/len(var/list/l)
	return l.len

/datum/reinforcements

	var/started = FALSE

	var/british_countdown = 50
	var/pirates_countdown = 50

	var/tick_len = TRUE // a decisecond

	// for now
	var/british_countdown_failure_reset = 50
	var/pirates_countdown_failure_reset = 50


	var/british_countdown_success_reset = 300
	var/pirates_countdown_success_reset = 300


	var/max_british_reinforcements = 100
	var/max_pirates_reinforcements = 100


	var/reinforcement_add_limit_british = 9
	var/reinforcement_add_limit_pirates = 12


	var/reinforcement_spawn_req = 1

	var/reinforcement_difference_cutoff = 12 // once one side has this many more reinforcements than the other, lock it until that's untrue

	var/reinforcements_granted[2] // keep track of how many troops we've given to british, how many to pirates, for autobalance

	var/locked[2] // lock british or pirates based on reinforcements_granted[]

	var/reinforcement_pool[2] // how many people are trying to join for each side

	var/allow_quickspawn[2]

	var/showed_permalock_message[2]

/datum/reinforcements/New()
	..()


	reinforcements_granted[PIRATES] = FALSE
	reinforcements_granted[BRITISH] = FALSE


	locked[PIRATES] = FALSE
	locked[BRITISH] = FALSE


	reinforcement_pool[PIRATES] = list()
	reinforcement_pool[BRITISH] = list()

	allow_quickspawn[PIRATES] = FALSE
	allow_quickspawn[BRITISH] = FALSE

	showed_permalock_message[PIRATES] = FALSE
	showed_permalock_message[BRITISH] = FALSE

/datum/reinforcements/proc/is_ready()
	. = (map ? map.reinforcements_ready() : game_started)
	if (map && !map.reinforcements)
		. = FALSE

/datum/reinforcements/proc/trytostartup()

	if (!is_ready())
		return FALSE

	if (started)
		return TRUE

	started = TRUE

	/* new formulas for determining how reinforcements work, directly determined
	 * by the number of clients when we start up. */

	max_british_reinforcements = max(1, round(clients.len * 0.42))
	max_pirates_reinforcements = max(1, round(clients.len * 0.58))

	reinforcement_add_limit_british = max(3, round(clients.len * 0.14))
	reinforcement_add_limit_pirates = max(3, round(clients.len * 0.19))
	reinforcement_spawn_req = 1
//	reinforcement_spawn_req = max(1, round(clients.len * 0.06))
//	reinforcement_spawn_req = 1 //to prevent bugs - Taislin
	reinforcement_difference_cutoff = max(3, round(clients.len * 0.19))

	world << "<span class = 'danger'>Reinforcements require <b>[reinforcement_spawn_req]</b> [reinforcement_spawn_req == 1 ? "person" : "people"] to fill a queue.</span>"

	return TRUE

/datum/reinforcements/proc/tick()
	if (map.front == "Eastern")
		if (reinforcement_pool[PIRATES] && reinforcement_pool[BRITISH])
			for (var/mob/new_player/np in reinforcement_pool[PIRATES])
				if (!np || !np.client)
					reinforcement_pool[PIRATES] -= np
			for (var/mob/new_player/np in reinforcement_pool[BRITISH])
				if (!np || !np.client)
					reinforcement_pool[BRITISH] -= np

		pirates_countdown = pirates_countdown - tick_len
		if (pirates_countdown < 1)
			if (!reset_pirates_timer())
				pirates_countdown = pirates_countdown_failure_reset
			else
				pirates_countdown = pirates_countdown_success_reset
				allow_quickspawn[PIRATES] = FALSE

		pirates_countdown = pirates_countdown - tick_len
		if (pirates_countdown < 1)
			if (!reset_pirates_timer())
				pirates_countdown = pirates_countdown_failure_reset
			else
				pirates_countdown = pirates_countdown_success_reset
				allow_quickspawn[BRITISH] = FALSE
	if (map.front == "Pacific")
		if (reinforcement_pool[PIRATES] && reinforcement_pool[BRITISH])
			for (var/mob/new_player/np in reinforcement_pool[PIRATES])
				if (!np || !np.client)
					reinforcement_pool[PIRATES] -= np
			for (var/mob/new_player/np in reinforcement_pool[BRITISH])
				if (!np || !np.client)
					reinforcement_pool[BRITISH] -= np

		pirates_countdown = pirates_countdown - tick_len
		if (pirates_countdown < 1)
			if (!reset_pirates_timer())
				pirates_countdown = pirates_countdown_failure_reset
			else
				pirates_countdown = pirates_countdown_success_reset
				allow_quickspawn[PIRATES] = FALSE

		pirates_countdown = pirates_countdown - tick_len
		if (pirates_countdown < 1)
			if (!reset_pirates_timer())
				pirates_countdown = pirates_countdown_failure_reset
			else
				pirates_countdown = pirates_countdown_success_reset
				allow_quickspawn[BRITISH] = FALSE

/datum/reinforcements/proc/add(var/mob/new_player/np, side)

	var/nope[2]

	switch (side)
		if (BRITISH)
			if (len(reinforcement_pool[BRITISH]) >= reinforcement_add_limit_british || (reinforcements_granted[BRITISH] + len(reinforcement_pool[BRITISH])+1) > max_british_reinforcements)
				nope[BRITISH] = TRUE
			else
				nope[BRITISH] = FALSE
		if (PIRATES)
			if (len(reinforcement_pool[PIRATES]) >= reinforcement_add_limit_pirates || (reinforcements_granted[PIRATES] + len(reinforcement_pool[PIRATES])+1) > max_pirates_reinforcements)
				nope[PIRATES] = TRUE
			else
				nope[PIRATES] = FALSE

	if (locked[side])
		np << "<span class = 'danger'>This side is locked for joining.</span>"
		return

	if (nope[side])
		np << "<span class = 'danger'>Sorry, too many people are attempting to join this side already.</span>"
		return

	if (locked[side])
		np << "<span class = 'danger'>This side is locked for joining.</span>"
		return

	//remove them from all pools, just in case
	var/list/u = reinforcement_pool[PIRATES]
	var/list/j = reinforcement_pool[BRITISH]

	if (u.Find(np))
		u -= np
	if (j.Find(np))
		j -= np

	var/sname[0]

	sname[BRITISH] = "British"
	sname[PIRATES] = "Pirate"

	np << "<span class = 'danger'>You have joined a queue for [sname[side]] reinforcements; please wait until the timer reaches 0 seconds to spawn.</span>"
	var/list/l = reinforcement_pool[side]
	l += np

/datum/reinforcements/proc/remove(var/mob/new_player/np, side)
	var/list/l = reinforcement_pool[side]
	if (l.Find(np))
		l -= np

/datum/reinforcements/proc/has(var/mob/new_player/np, side_or_null)

	if (side_or_null)
		var/side = side_or_null
		var/list/l = reinforcement_pool[side]
		if (l.Find(np))
			return TRUE
	else
		var/list/u = reinforcement_pool[PIRATES]
		var/list/j = reinforcement_pool[BRITISH]

		if (u.Find(np) || j.Find(np))
			return TRUE

	return FALSE

/datum/reinforcements/proc/reset_pirates_timer()

	var/ret = FALSE
	var/list/l = reinforcement_pool[PIRATES]
	if (l.len < reinforcement_spawn_req && !allow_quickspawn[PIRATES])
		for (var/mob/new_player/np in l)
			np << "<span class='danger'>Failed to spawn a new Allied squadron. [reinforcement_spawn_req - l.len] more draftees needed."
		return ret
	else if (map && map.has_occupied_base(PIRATES))
		for (var/mob/new_player/np in l)
			np << "<span class='danger'>The Axis forces are currently occupying the Allied base! Reinforcements can't be sent."
		return ret
	if (map.front == "Eastern")
		for (var/mob/new_player/np in l)
			if (np)
				np.LateSpawnForced("Sovietsky Soldat", TRUE, TRUE)
				reinforcements_granted[PIRATES] = reinforcements_granted[PIRATES]+1
				ret = TRUE
	if (map.front == "Pacific")
		for (var/mob/new_player/np in l)
			if (np) // maybe helps with logged out nps
				np.LateSpawnForced("Sailor", TRUE, TRUE)
				reinforcements_granted[BRITISH] = reinforcements_granted[BRITISH]+1
				ret = TRUE
	reinforcement_pool[PIRATES] = list()
	lock_check()
/datum/reinforcements/proc/reset_british_timer()
	var/ret = FALSE
	var/list/l = reinforcement_pool[BRITISH]
	if (l.len < reinforcement_spawn_req && !allow_quickspawn[BRITISH])
		for (var/mob/new_player/np in l)
			np << "<span class='danger'>Failed to spawn a new Axis squadron. [reinforcement_spawn_req - l.len] more draftees needed."
		return ret
	else if (map && map.has_occupied_base(BRITISH))
		for (var/mob/new_player/np in l)
			np << "<span class='danger'>The Allies are currently occupying the Axis base! Reinforcements can't be sent."
		return ret
	if (map.front == "Eastern")
		for (var/mob/new_player/np in l)
			if (np) // maybe helps with logged out nps
				np.LateSpawnForced("Soldat", TRUE, TRUE)
				reinforcements_granted[BRITISH] = reinforcements_granted[BRITISH]+1
				ret = TRUE
	if (map.front == "Pacific")
		for (var/mob/new_player/np in l)
			if (np) // maybe helps with logged out nps
				np.LateSpawnForced("Pirate", TRUE, TRUE)
				reinforcements_granted[PIRATES] = reinforcements_granted[PIRATES]+1
				ret = TRUE
	reinforcement_pool[BRITISH] = list()
	lock_check()



/datum/reinforcements/proc/r_british()
	var/list/l = reinforcement_pool[BRITISH]
	return l.len

/datum/reinforcements/proc/r_pirates()
	var/list/l = reinforcement_pool[PIRATES]
	return l.len

datum/reinforcements/proc/lock_check()

	var/r = reinforcements_granted[PIRATES]
	var/g = reinforcements_granted[BRITISH]
	if (abs(r-g) >= reinforcement_difference_cutoff)
		if (max(r,g) == r)
			locked[BRITISH] = TRUE
		else
			locked[PIRATES] = TRUE

	else
		locked[BRITISH] = FALSE
		locked[PIRATES] = FALSE

	if (is_permalocked(PIRATES))

		if (!showed_permalock_message[PIRATES])
			world << "<font size = 3>The Allied forces are out of reinforcements.</font>"
			showed_permalock_message[PIRATES] = TRUE

		locked[PIRATES] = TRUE
		locked[BRITISH] = TRUE // since pirates get more reinforcements,

		if (!is_permalocked(BRITISH))
			locked[BRITISH] = FALSE

	if (is_permalocked(BRITISH))

		if (!showed_permalock_message[BRITISH])
			world << "<font size = 3>The Axis forces are out of reinforcements.</font>"
			showed_permalock_message[BRITISH] = TRUE

		locked[BRITISH] = TRUE

		if (!is_permalocked(PIRATES))
			locked[PIRATES] = FALSE

	if (is_permalocked(BRITISH))

		if (!showed_permalock_message[BRITISH])
			world << "<font size = 3>The Royal Navy is out of reinforcements.</font>"
			showed_permalock_message[BRITISH] = TRUE

		locked[BRITISH] = TRUE

		if (!is_permalocked(PIRATES))
			locked[PIRATES] = FALSE

	if (is_permalocked(PIRATES))

		if (!showed_permalock_message[PIRATES])
			world << "<font size = 3>The Axis forces are out of reinforcements.</font>"
			showed_permalock_message[PIRATES] = TRUE

		locked[PIRATES] = TRUE

		if (!is_permalocked(BRITISH))
			locked[BRITISH] = FALSE

/datum/reinforcements/proc/is_permalocked(side)
	switch (side)
		if (BRITISH)
			if (reinforcements_granted[BRITISH] >= max_british_reinforcements)
				return TRUE
		if (PIRATES)
			if (reinforcements_granted[PIRATES] >= max_pirates_reinforcements)
				return TRUE
	return FALSE

/datum/reinforcements/proc/finished()
	if (map.faction_organization != BRITISH)
		return is_permalocked(BRITISH) && is_permalocked(PIRATES)
	else
		return is_permalocked(BRITISH) && is_permalocked(PIRATES)

/datum/reinforcements/proc/get_status_addendums()

	var/list/l = list()

	if (is_ready())
		if (map && map.has_occupied_base(BRITISH))
			l += "The Axis base is currently occupied; Reinforcements cannot be deployed."
		else
			l += "Axis:: "
			l += "Deployed: [reinforcements_granted[BRITISH]]/[max_british_reinforcements]"
			l += "Deploying: [r_british()]/[reinforcement_add_limit_british] ([reinforcement_spawn_req] needed) in [british_countdown] seconds"
			l += "Locked: [locked[BRITISH] ? "Yes" : "No"]"

		l += ""

		if (map && map.has_occupied_base(PIRATES))
			l += "The Allied base is currently occupied; Reinforcements cannot be deployed."
		else
			l += "Allies:: "
			l += "Deployed: [reinforcements_granted[PIRATES]]/[max_pirates_reinforcements]"
			l += "Deploying: [r_pirates()]/[reinforcement_add_limit_pirates] ([reinforcement_spawn_req] needed) in [pirates_countdown] seconds"
			l += "Locked: [locked[PIRATES] ? "Yes" : "No"]"

	return l

