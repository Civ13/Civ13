var/datum/reinforcements/reinforcements_master = null


/proc/len(var/list/l)
	return l.len

/datum/reinforcements

	var/started = FALSE

	var/soviet_countdown = 50
	var/german_countdown = 50
	var/usa_countdown = 50
	var/japan_countdown = 50

	var/tick_len = TRUE // a decisecond

	// for now
	var/soviet_countdown_failure_reset = 50
	var/german_countdown_failure_reset = 50
	var/usa_countdown_failure_reset = 50
	var/japan_countdown_failure_reset = 50

	var/soviet_countdown_success_reset = 300
	var/german_countdown_success_reset = 300
	var/usa_countdown_success_reset = 300
	var/japan_countdown_success_reset = 300

	var/max_german_reinforcements = 100
	var/max_soviet_reinforcements = 100
	var/max_usa_reinforcements = 100
	var/max_japan_reinforcements = 100

	var/reinforcement_add_limit_german = 9
	var/reinforcement_add_limit_soviet = 12
	var/reinforcement_add_limit_usa = 9
	var/reinforcement_add_limit_japan = 12

	var/reinforcement_spawn_req = 1

	var/reinforcement_difference_cutoff = 12 // once one side has this many more reinforcements than the other, lock it until that's untrue

	var/reinforcements_granted[4] // keep track of how many troops we've given to germans, how many to soviets, for autobalance

	var/locked[4] // lock german or soviet based on reinforcements_granted[]

	var/reinforcement_pool[4] // how many people are trying to join for each side

	var/allow_quickspawn[4]

	var/showed_permalock_message[4]

/datum/reinforcements/New()
	..()

	reinforcements_granted[SOVIET] = FALSE
	reinforcements_granted[GERMAN] = FALSE
	reinforcements_granted[PIRATES] = FALSE
	reinforcements_granted[BRITISH] = FALSE

	locked[SOVIET] = FALSE
	locked[GERMAN] = FALSE
	locked[PIRATES] = FALSE
	locked[BRITISH] = FALSE

	reinforcement_pool[SOVIET] = list()
	reinforcement_pool[GERMAN] = list()
	reinforcement_pool[PIRATES] = list()
	reinforcement_pool[BRITISH] = list()

	allow_quickspawn[SOVIET] = FALSE
	allow_quickspawn[GERMAN] = FALSE
	allow_quickspawn[PIRATES] = FALSE
	allow_quickspawn[BRITISH] = FALSE

	showed_permalock_message[GERMAN] = FALSE
	showed_permalock_message[SOVIET] = FALSE
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

	max_german_reinforcements = max(1, round(clients.len * 0.42))
	max_soviet_reinforcements = max(1, round(clients.len * 0.58))
	max_usa_reinforcements = max(1, round(clients.len * 0.42))
	max_japan_reinforcements = max(1, round(clients.len * 0.58))
	reinforcement_add_limit_german = max(3, round(clients.len * 0.14))
	reinforcement_add_limit_soviet = max(3, round(clients.len * 0.19))
	reinforcement_add_limit_usa = max(3, round(clients.len * 0.14))
	reinforcement_add_limit_japan = max(3, round(clients.len * 0.19))
	reinforcement_spawn_req = 1
//	reinforcement_spawn_req = max(1, round(clients.len * 0.06))
//	reinforcement_spawn_req = 1 //to prevent bugs - Taislin
	reinforcement_difference_cutoff = max(3, round(clients.len * 0.19))

	world << "<span class = 'danger'>Reinforcements require <b>[reinforcement_spawn_req]</b> [reinforcement_spawn_req == 1 ? "person" : "people"] to fill a queue.</span>"

	return TRUE

/datum/reinforcements/proc/tick()

	if (prob(1) && prob(2) && prob(75)) // events
		if (prob(50))
			if (!locked[SOVIET])
				soviet_countdown = soviet_countdown_success_reset*2
				world << "<font size = 3>Due to harsh combat in other areas of the front, Soviet reinforcements will not be available for a while.</font>"
		else if (!locked[GERMAN])
			german_countdown = german_countdown_success_reset*2
			world << "<font size = 3>Due to harsh combat in other areas on the front, German reinforcements will not be available for a while.</font>"
		else if (!locked[BRITISH])
			japan_countdown = japan_countdown_success_reset*2
			world << "<font size = 3>Due to harsh combat in other areas on the front, Japanese reinforcements will not be available for a while.</font>"
		else if (!locked[PIRATES])
			usa_countdown = usa_countdown_success_reset*2
			world << "<font size = 3>Due to harsh combat in other areas on the front, American reinforcements will not be available for a while.</font>"
	if (map.front == "Eastern")
		if (reinforcement_pool[SOVIET] && reinforcement_pool[GERMAN])
			for (var/mob/new_player/np in reinforcement_pool[SOVIET])
				if (!np || !np.client)
					reinforcement_pool[SOVIET] -= np
			for (var/mob/new_player/np in reinforcement_pool[GERMAN])
				if (!np || !np.client)
					reinforcement_pool[GERMAN] -= np

		soviet_countdown = soviet_countdown - tick_len
		if (soviet_countdown < 1)
			if (!reset_soviet_timer())
				soviet_countdown = soviet_countdown_failure_reset
			else
				soviet_countdown = soviet_countdown_success_reset
				allow_quickspawn[SOVIET] = FALSE

		german_countdown = german_countdown - tick_len
		if (german_countdown < 1)
			if (!reset_german_timer())
				german_countdown = german_countdown_failure_reset
			else
				german_countdown = german_countdown_success_reset
				allow_quickspawn[GERMAN] = FALSE
	if (map.front == "Pacific")
		if (reinforcement_pool[SOVIET] && reinforcement_pool[GERMAN])
			for (var/mob/new_player/np in reinforcement_pool[SOVIET])
				if (!np || !np.client)
					reinforcement_pool[SOVIET] -= np
			for (var/mob/new_player/np in reinforcement_pool[GERMAN])
				if (!np || !np.client)
					reinforcement_pool[GERMAN] -= np

		soviet_countdown = soviet_countdown - tick_len
		if (soviet_countdown < 1)
			if (!reset_soviet_timer())
				soviet_countdown = soviet_countdown_failure_reset
			else
				soviet_countdown = soviet_countdown_success_reset
				allow_quickspawn[SOVIET] = FALSE

		german_countdown = german_countdown - tick_len
		if (german_countdown < 1)
			if (!reset_german_timer())
				german_countdown = german_countdown_failure_reset
			else
				german_countdown = german_countdown_success_reset
				allow_quickspawn[GERMAN] = FALSE

/datum/reinforcements/proc/add(var/mob/new_player/np, side)

	var/nope[2]

	switch (side)
		if (SOVIET)
			if (len(reinforcement_pool[SOVIET]) >= reinforcement_add_limit_soviet || (reinforcements_granted[SOVIET] + len(reinforcement_pool[SOVIET])+1) > max_soviet_reinforcements)
				nope[SOVIET] = TRUE
			else
				nope[SOVIET] = FALSE
		if (GERMAN)
			if (len(reinforcement_pool[GERMAN]) >= reinforcement_add_limit_german || (reinforcements_granted[GERMAN] + len(reinforcement_pool[GERMAN])+1) > max_german_reinforcements)
				nope[GERMAN] = TRUE
			else
				nope[BRITISH] = FALSE
		if (BRITISH)
			if (len(reinforcement_pool[BRITISH]) >= reinforcement_add_limit_japan || (reinforcements_granted[BRITISH] + len(reinforcement_pool[BRITISH])+1) > max_japan_reinforcements)
				nope[BRITISH] = TRUE
			else
				nope[BRITISH] = FALSE
		if (PIRATES)
			if (len(reinforcement_pool[PIRATES]) >= reinforcement_add_limit_usa || (reinforcements_granted[PIRATES] + len(reinforcement_pool[PIRATES])+1) > max_usa_reinforcements)
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
	var/list/r = reinforcement_pool[SOVIET]
	var/list/g = reinforcement_pool[GERMAN]
	var/list/u = reinforcement_pool[PIRATES]
	var/list/j = reinforcement_pool[BRITISH]

	if (r.Find(np))
		r -= np
	if (g.Find(np))
		g -= np
	if (u.Find(np))
		u -= np
	if (j.Find(np))
		j -= np

	var/sname[0]

	sname[SOVIET] = "Allied"
	sname[GERMAN] = "Axis"
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
		var/list/r = reinforcement_pool[SOVIET]
		var/list/g = reinforcement_pool[GERMAN]
		var/list/u = reinforcement_pool[PIRATES]
		var/list/j = reinforcement_pool[BRITISH]

		if (r.Find(np) || g.Find(np) || u.Find(np) || j.Find(np))
			return TRUE

	return FALSE

/datum/reinforcements/proc/reset_soviet_timer()

	var/ret = FALSE
	var/list/l = reinforcement_pool[SOVIET]
	if (l.len < reinforcement_spawn_req && !allow_quickspawn[SOVIET])
		for (var/mob/new_player/np in l)
			np << "<span class='danger'>Failed to spawn a new Allied squadron. [reinforcement_spawn_req - l.len] more draftees needed."
		return ret
	else if (map && map.has_occupied_base(SOVIET))
		for (var/mob/new_player/np in l)
			np << "<span class='danger'>The Axis forces are currently occupying the Allied base! Reinforcements can't be sent."
		return ret
	if (map.front == "Eastern")
		for (var/mob/new_player/np in l)
			if (np)
				np.LateSpawnForced("Sovietsky Soldat", TRUE, TRUE)
				reinforcements_granted[SOVIET] = reinforcements_granted[SOVIET]+1
				ret = TRUE
	if (map.front == "Pacific")
		for (var/mob/new_player/np in l)
			if (np) // maybe helps with logged out nps
				np.LateSpawnForced("Sailor", TRUE, TRUE)
				reinforcements_granted[BRITISH] = reinforcements_granted[BRITISH]+1
				ret = TRUE
	reinforcement_pool[SOVIET] = list()
	lock_check()
/datum/reinforcements/proc/reset_german_timer()
	var/ret = FALSE
	var/list/l = reinforcement_pool[GERMAN]
	if (l.len < reinforcement_spawn_req && !allow_quickspawn[GERMAN])
		for (var/mob/new_player/np in l)
			np << "<span class='danger'>Failed to spawn a new Axis squadron. [reinforcement_spawn_req - l.len] more draftees needed."
		return ret
	else if (map && map.has_occupied_base(GERMAN))
		for (var/mob/new_player/np in l)
			np << "<span class='danger'>The Allies are currently occupying the Axis base! Reinforcements can't be sent."
		return ret
	if (map.front == "Eastern")
		for (var/mob/new_player/np in l)
			if (np) // maybe helps with logged out nps
				np.LateSpawnForced("Soldat", TRUE, TRUE)
				reinforcements_granted[GERMAN] = reinforcements_granted[GERMAN]+1
				ret = TRUE
	if (map.front == "Pacific")
		for (var/mob/new_player/np in l)
			if (np) // maybe helps with logged out nps
				np.LateSpawnForced("Pirate", TRUE, TRUE)
				reinforcements_granted[PIRATES] = reinforcements_granted[PIRATES]+1
				ret = TRUE
	reinforcement_pool[GERMAN] = list()
	lock_check()



/datum/reinforcements/proc/r_german()
	var/list/l = reinforcement_pool[GERMAN]
	return l.len

/datum/reinforcements/proc/r_soviet()
	var/list/l = reinforcement_pool[SOVIET]
	return l.len

datum/reinforcements/proc/lock_check()

	var/r = reinforcements_granted[SOVIET]
	var/g = reinforcements_granted[GERMAN]
	var/u = reinforcements_granted[PIRATES]
	var/j = reinforcements_granted[BRITISH]
	if (map.faction_organization != BRITISH)
		if (abs(r-g) >= reinforcement_difference_cutoff)

			if (max(r,g) == r)
				locked[SOVIET] = TRUE
			else
				locked[GERMAN] = TRUE

		else
			locked[SOVIET] = FALSE
			locked[GERMAN] = FALSE
	else
		if (abs(j-u) >= reinforcement_difference_cutoff)

			if (max(j,u) == j)
				locked[BRITISH] = TRUE
			else
				locked[PIRATES] = TRUE

		else
			locked[BRITISH] = FALSE
			locked[PIRATES] = FALSE

	if (is_permalocked(SOVIET))

		if (!showed_permalock_message[SOVIET])
			world << "<font size = 3>The Allied forces are out of reinforcements.</font>"
			showed_permalock_message[SOVIET] = TRUE

		locked[SOVIET] = TRUE
		locked[GERMAN] = TRUE // since soviets get more reinforcements,

		if (!is_permalocked(GERMAN))
			locked[GERMAN] = FALSE

	if (is_permalocked(GERMAN))

		if (!showed_permalock_message[GERMAN])
			world << "<font size = 3>The Axis forces are out of reinforcements.</font>"
			showed_permalock_message[GERMAN] = TRUE

		locked[GERMAN] = TRUE

		if (!is_permalocked(SOVIET))
			locked[SOVIET] = FALSE

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
		if (GERMAN)
			if (reinforcements_granted[GERMAN] >= max_german_reinforcements)
				return TRUE
		if (SOVIET)
			if (reinforcements_granted[SOVIET] >= max_soviet_reinforcements)
				return TRUE
		if (PIRATES)
			if (reinforcements_granted[PIRATES] >= max_usa_reinforcements)
				return TRUE
		if (BRITISH)
			if (reinforcements_granted[BRITISH] >= max_japan_reinforcements)
				return TRUE
	return FALSE

/datum/reinforcements/proc/finished()
	if (map.faction_organization != BRITISH)
		return is_permalocked(GERMAN) && is_permalocked(SOVIET)
	else
		return is_permalocked(BRITISH) && is_permalocked(PIRATES)

/datum/reinforcements/proc/get_status_addendums()

	var/list/l = list()

	if (is_ready())
		if (map && map.has_occupied_base(GERMAN))
			l += "The Axis base is currently occupied; Reinforcements cannot be deployed."
		else
			l += "Axis:: "
			l += "Deployed: [reinforcements_granted[GERMAN]]/[max_german_reinforcements]"
			l += "Deploying: [r_german()]/[reinforcement_add_limit_german] ([reinforcement_spawn_req] needed) in [german_countdown] seconds"
			l += "Locked: [locked[GERMAN] ? "Yes" : "No"]"

		l += ""

		if (map && map.has_occupied_base(SOVIET))
			l += "The Allied base is currently occupied; Reinforcements cannot be deployed."
		else
			l += "Allies:: "
			l += "Deployed: [reinforcements_granted[SOVIET]]/[max_soviet_reinforcements]"
			l += "Deploying: [r_soviet()]/[reinforcement_add_limit_soviet] ([reinforcement_spawn_req] needed) in [soviet_countdown] seconds"
			l += "Locked: [locked[SOVIET] ? "Yes" : "No"]"

	return l

