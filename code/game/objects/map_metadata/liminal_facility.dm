// Liminal Facility finite escape round. Reached only by compiling the exported
// Liminal map as the selected map; no map list or vote offers MAP_LIMINAL_FACILITY.
// Deliberately does not reuse the Lights Out constructor (jungle hazards,
// piranhas, extraction-area deletion) or its poll-count extraction timer.
/obj/map_metadata/liminal_facility
	ID = MAP_LIMINAL_FACILITY
	title = "Liminal Facility"
	description = "Find the route marker, reset the service panel and leave through the egress before the facility closes in."
	no_winner = "The team is still inside."
	faction_organization = list(CIVILIAN)
	faction1 = CIVILIAN
	faction2 = CIVILIAN
	roundend_condition_sides = list(list(CIVILIAN) = /area/caribbean/liminal/extraction)
	faction_distribution_coeffs = list(CIVILIAN = 1)
	age = "1990"
	ordinal_age = 7
	is_singlefaction = TRUE
	is_RP = TRUE
	gamemode_vote = FALSE
	gamemode = "Liminal Escape"
	battle_name = "the facility"
	mission_start_message = "<font size=4>Find the route marker, reset the service panel, then hold the egress together to escape.</font>"
	respawn_delay = 36000
	valid_weather_types = list(WEATHER_NONE)
	no_time_of_day_cycle = TRUE
	times_of_day = list("Night")
	ambience = list()
	research_active = FALSE
	override_global_recipes = "liminal" // no recipe list: only the utensil fallback
	// Tunables, validated by /datum/liminal_round/proc/configure.
	var/hold_seconds = 20
	var/deadline_minutes = 15
	var/team_cap = 4
	var/scenario_year = 1990
	var/threat_enabled = TRUE
	var/threat_type = /mob/living/simple_animal/hostile/echofiend
	var/threat_clearance = 7 // no participant this close to the site, or seeing it
	var/mob/living/threat
	var/datum/liminal_round/liminal
	var/datum/liminal_era_policy/era_policy
	var/announced = FALSE

/obj/map_metadata/liminal_facility/New()
	..()
	liminal = new
	era_policy = new(scenario_year)
	if (!liminal.configure(hold_seconds, deadline_minutes, team_cap))
		liminal.fail("CONFIG")
	spawn(0)
		liminal_loop()

/obj/map_metadata/liminal_facility/proc/prepare()
	if (liminal.state != "VALIDATED")
		return liminal.state == "READY" || liminal.state == "EXPLORING"
	if (!era_policy.admit_z(z))
		liminal.fail("ERA_POLICY")
		log_game("Liminal era policy refused: [jointext(era_policy.refused, ", ")]")
		return FALSE
	return liminal.ready(era_policy)

/obj/map_metadata/liminal_facility/proc/join(mob/living/human/H)
	if (!prepare())
		return FALSE
	return liminal.admit(H, world.time)

/obj/map_metadata/liminal_facility/proc/survey()
	var/alive = 0
	var/in_zone = 0
	for (var/mob/living/human/H in liminal.participants)
		if (QDELETED(H) || H.stat == DEAD)
			continue
		alive++
		if (H.stat == CONSCIOUS && istype(get_area(H), /area/caribbean/liminal/extraction))
			in_zone++
	return list(alive, in_zone)

/obj/map_metadata/liminal_facility/proc/advance(now)
	var/before = liminal.state
	var/list/counts = survey()
	liminal.advance(now, counts[1], counts[2])
	if (liminal.state == before)
		return
	switch (liminal.state)
		if ("EXTRACTING")
			to_chat(world, "<font size=3><span class='notice'>Hold the egress for [hold_seconds] seconds!</span></font>")
		if ("TASKS_DONE")
			if (before == "EXTRACTING")
				to_chat(world, "<font size=3><span class='warning'>Nobody is holding the egress.</span></font>")
	if (liminal.terminal())
		finish()

// The exported threat site, or null. The exporter places at most one
// LiminalThreat landmark; like other named landmarks it leaves only its turf.
/obj/map_metadata/liminal_facility/proc/threat_site()
	var/list/sites = latejoin_turfs["LiminalThreat"]
	if (!islist(sites))
		return null
	for (var/turf/T in sites)
		if (T.z == z)
			return T
	return null

// Clear when no living human (participant or late explorer, wherever they
// stand, even inside a locker) is within threat_clearance tiles or has an
// unblocked line to the site within a screen. hearers() checks opacity only,
// so a dark corridor does not count as hiding the site.
/obj/map_metadata/liminal_facility/proc/threat_site_clear(turf/site)
	var/list/sightline = hearers(world.view, site)
	for (var/mob/living/human/H in human_mob_list)
		if (QDELETED(H) || H.stat == DEAD)
			continue
		var/turf/T = get_turf(H)
		if (!T || T.z != site.z)
			continue
		if (get_dist(T, site) <= threat_clearance || (H in sightline))
			return FALSE
	return TRUE

// Places the single threat once its grace has passed and its site is out of
// sight; a map without a site, or with threats disabled, never gets one.
/obj/map_metadata/liminal_facility/proc/place_threat(now)
	if (!liminal.threat_due(now))
		return FALSE
	var/turf/site = threat_enabled ? threat_site() : null
	if (!site)
		liminal.threat_placed(FALSE)
		return FALSE
	// A restored world restarts the round datum, but not its mobs.
	for (var/mob/living/M in mob_list)
		if (istype(M, threat_type) && M.z == site.z)
			threat = M
			liminal.threat_placed(TRUE)
			return FALSE
	if (!threat_site_clear(site))
		return FALSE
	threat = new threat_type(site)
	liminal.threat_placed(TRUE)
	log_game("Liminal threat [threat] placed at [site.x],[site.y],[site.z]")
	return TRUE

/obj/map_metadata/liminal_facility/proc/finish()
	if (announced)
		return
	announced = TRUE
	var/message = liminal.state == "ESCAPED" ? "The team has escaped the facility!" : "The facility has claimed the team ([liminal.end_reason == "DEADLINE" ? "time ran out" : "no one survived"])."
	to_chat(world, "<font size=4><span class='notice'>[message]</span></font>")
	win_condition_spam_check = TRUE
	ticker.finished = TRUE

/obj/map_metadata/liminal_facility/proc/liminal_loop()
	while (!liminal.terminal())
		sleep(10)
		if (ticker && ticker.current_state == GAME_STATE_PLAYING)
			prepare()
			place_threat(world.time)
			advance(world.time)
	finish()

/obj/map_metadata/liminal_facility/update_win_condition()
	if (liminal && liminal.terminal())
		finish()
		return FALSE
	next_win = -1
	current_win_condition = no_winner
	win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/datum/job/civilian/liminal_surveyor
	title = "Facility Surveyor"
	spawn_location = "JoinLateLiminal"
	allowed_maps = list(MAP_LIMINAL_FACILITY)
	min_positions = 4
	max_positions = 4
	can_be_female = TRUE

/datum/job/civilian/liminal_surveyor/equip(mob/living/human/H)
	var/obj/map_metadata/liminal_facility/M = map
	if (!H || !istype(M))
		return FALSE
	var/datum/liminal_era_policy/P = M.era_policy
	P.issue(/obj/item/clothing/shoes/laceup, H, slot_shoes)
	P.issue(/obj/item/clothing/under/mechanic_outfit, H, slot_w_uniform)
	P.issue(/obj/item/flashlight/flashlight, H, slot_belt)
	if (M.join(H))
		H.add_note("Role", "Find the route marker, reset the service panel, then hold the egress with your team for [M.hold_seconds] seconds. You have [M.deadline_minutes] minutes.")
	else
		H.add_note("Role", "You arrived after the team set out. You can explore, but only the original team can complete the escape.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("crafting", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	H.setStat("dexterity", STAT_NORMAL)
	H.setStat("swords", STAT_NORMAL)
	H.setStat("pistol", STAT_NORMAL)
	H.setStat("bows", STAT_NORMAL)
	H.setStat("medical", STAT_NORMAL)
	return TRUE
