// Broadside: a French man-of-war against a pirate ship on open sea. Both
// ships sail (code/modules/craft/): the crews weigh anchor, set a course at
// the tiller, close on the enemy and fire on the boatswain's call. A side
// wins by sinking the other ship, or by taking her tiller and holding it.
// The map is written by tools/broadside/make_map.py.

#define BROADSIDE_PACE 4               // The ships make way this many times faster than at sea.
#define BROADSIDE_SUNK_SHARE 0.6       // A ship with less of her planking left than this is sunk.
#define BROADSIDE_CAPTURE_TIME 600     // Ticks boarders must hold a tiller to take the ship.
#define BROADSIDE_TIME_LIMIT 36000     // An hour of play.

var/global/list/broadside_tillers = list()

// The ships' planking. Laid afloat, so the open sea does not swallow it
// before the tillers commission the hulls.
/obj/covers/repairedfloor/ship/afloat
	afloat = TRUE

/obj/structure/hull_tiller/broadside
	desc = "The ship's tiller. Weigh anchor, set the sails and steer her into the enemy."
	var/side = null              // The faction that sails her.
	var/ship_name = "ship"
	var/bow = EAST
	var/tmp/start_planks = 0
	var/tmp/held_since = 0       // When boarders took the tiller, or 0.
	var/tmp/sunk = FALSE

/obj/structure/hull_tiller/broadside/french
	side = FRENCH
	ship_name = "Foudroyant"
	bow = EAST

/obj/structure/hull_tiller/broadside/pirates
	side = PIRATES
	ship_name = "Black Gull"
	bow = WEST

/obj/structure/hull_tiller/broadside/New()
	..()
	broadside_tillers += src

/obj/structure/hull_tiller/broadside/Destroy()
	broadside_tillers -= src
	return ..()

// Shot cannot carry away the helm, and nobody can strike or refit her.
/obj/structure/hull_tiller/broadside/ex_act(severity)
	return

/obj/structure/hull_tiller/broadside/attack_hand(mob/living/human/H)
	if (istype(H) && map && !map.game_really_started())
		to_chat(H, SPAN_WARNING("The ships wait at anchor for the signal gun."))
		return
	if (istype(H) && craft && H.faction_text != side)
		to_chat(H, SPAN_WARNING("The [craft.name] is not your ship. Hold her tiller and she is yours."))
		return
	return ..()

/obj/structure/hull_tiller/broadside/commission_menu(mob/living/human/H)
	return

// Commissions the ship where the map laid her. Returns TRUE when she sails.
/obj/structure/hull_tiller/broadside/proc/launch()
	if (craft)
		return TRUE
	if (commission(ship_name, bow))
		return FALSE
	craft.pace = BROADSIDE_PACE
	craft.anchored = TRUE
	craft.fit_drives()
	// The guns are run out loaded for the first broadside.
	for (var/obj/structure/cannon/C in craft.body.aboard())
		if (!C.loaded.len)
			C.loaded += new C.ammotype(C)
	start_planks = planks()
	return TRUE

// Ship floors still in her hull.
/obj/structure/hull_tiller/broadside/proc/planks()
	. = 0
	var/datum/craft_body/built/B = body()
	if (!B)
		return
	for (var/turf/T in B.cells())
		if (hull_floor_in(T))
			.++

/obj/structure/hull_tiller/broadside/proc/is_sunk()
	if (sunk)
		return TRUE
	if (!craft || start_planks <= 0)
		return FALSE
	sunk = planks() < start_planks * BROADSIDE_SUNK_SHARE
	return sunk

// TRUE while boarders stand at her tiller and none of her crew are near.
/obj/structure/hull_tiller/broadside/proc/boarders_hold()
	var/boarders = FALSE
	for (var/mob/living/human/M in range(1, src))
		if (M.stat != DEAD && M.faction_text && M.faction_text != side)
			boarders = TRUE
			break
	if (!boarders)
		return FALSE
	for (var/mob/living/human/M in range(4, src))
		if (M.stat != DEAD && M.faction_text == side)
			return FALSE
	return TRUE

/proc/broadside_tiller_of(faction)
	for (var/obj/structure/hull_tiller/broadside/T in broadside_tillers)
		if (T.side == faction)
			return T
	return null

// Commissions every ship that is not yet sailing.
/proc/broadside_launch_all()
	for (var/obj/structure/hull_tiller/broadside/T in broadside_tillers)
		T.launch()

// Puts a new crewman on a free tile of his own ship, wherever she has sailed.
/proc/broadside_spawn_aboard(mob/living/human/H)
	if (!istype(H) || !map || map.ID != MAP_BROADSIDE)
		return FALSE
	var/obj/structure/hull_tiller/broadside/T = broadside_tiller_of(H.faction_text)
	if (!T || !T.launch())
		return FALSE
	var/datum/craft_body/built/B = T.body()
	var/list/free = list()
	for (var/turf/D in B.cells())
		if (!hull_floor_in(D) || D.density || (locate(/mob/living) in D))
			continue
		var/blocked = FALSE
		for (var/obj/O in D)
			if (O.density)
				blocked = TRUE
				break
		if (!blocked)
			free += D
	if (!free.len)
		return FALSE
	H.forceMove(pick(free))
	return TRUE

/obj/map_metadata/broadside
	ID = MAP_BROADSIDE
	title = "Broadside"
	description = "A French man-of-war and a pirate ship under sail. Close on the enemy and fire on the boatswain's call: sink her or take her tiller."
	lobby_icon = "icons/lobby/imperial.png"
	caribbean_blocking_area_types = list()
	respawn_delay = 300
	no_winner = "Both ships are still afloat."
	gamemode = "Broadside"

	faction_organization = list(
		FRENCH,
		PIRATES)

	roundend_condition_sides = list(
		list(FRENCH) = /area/caribbean/sea/sea,
		list(PIRATES) = /area/caribbean/sea/sea,
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(FRENCH = 0.5, PIRATES = 0.5)
	battle_name = "the broadside"
	mission_start_message = "<font size=4>Two ships at anchor on open sea. The signal gun fires in <b>3 minutes</b>: then weigh anchor, steer for the enemy and run out the guns.<br>A side wins by <b>sinking</b> the other ship or by <b>holding her tiller</b> for a minute.</font>"
	faction1 = FRENCH
	faction2 = PIRATES
	grace_wall_timer = 1800
	valid_weather_types = list(WEATHER_NONE)

/obj/map_metadata/broadside/roundend_condition_def2name(define)
	..()
	switch (define)
		if (FRENCH)
			return "French sailor"
		if (PIRATES)
			return "Pirate"

/obj/map_metadata/broadside/roundend_condition_def2army(define)
	..()
	switch (define)
		if (FRENCH)
			return "French Navy"
		if (PIRATES)
			return "Pirates"

/obj/map_metadata/broadside/army2name(army)
	..()
	switch (army)
		if ("French Navy")
			return "French sailor"
		if ("Pirates")
			return "Pirate"

/obj/map_metadata/broadside/cross_message(faction)
	if (faction == FRENCH)
		return "<font size = 4>The signal gun fires! Weigh anchor and steer for the enemy.</font>"
	return ""

/obj/map_metadata/broadside/reverse_cross_message(faction)
	return ""

/obj/map_metadata/broadside/proc/end_broadside(winner, loser, message)
	current_winner = roundend_condition_def2army(winner)
	current_loser = roundend_condition_def2army(loser)
	ticker.finished = TRUE
	next_win = -1
	current_win_condition = no_winner
	win_condition.hash = 0
	last_win_condition = win_condition.hash
	win_condition_spam_check = TRUE
	to_chat(world, "<font size = 4 color='yellow'><span class = 'notice'>[message]</span></font>")
	show_global_battle_report(null)

/obj/map_metadata/broadside/update_win_condition()
	if (win_condition_spam_check)
		return FALSE
	broadside_launch_all()
	for (var/obj/structure/hull_tiller/broadside/T in broadside_tillers)
		var/enemy = T.side == FRENCH ? PIRATES : FRENCH
		if (T.is_sunk())
			end_broadside(enemy, T.side, "The [T.ship_name] is shot to pieces and goes down! The [roundend_condition_def2army(enemy)] win the battle.")
			return FALSE
		if (!T.boarders_hold())
			if (T.held_since)
				T.held_since = 0
				to_chat(world, SPAN_NOTICE("<font size = 3>The crew of the [T.ship_name] retake her tiller!</font>"))
			continue
		if (!T.held_since)
			T.held_since = world.time
			to_chat(world, SPAN_DANGER("<font size = 3>Boarders hold the tiller of the [T.ship_name]! Her crew have a minute to take it back.</font>"))
		else if (world.time - T.held_since >= BROADSIDE_CAPTURE_TIME)
			end_broadside(enemy, T.side, "The [T.ship_name] strikes her colours! The [roundend_condition_def2army(enemy)] take her and win the battle.")
			return FALSE
	if (processes.ticker.playtime_elapsed >= BROADSIDE_TIME_LIMIT)
		end_broadside_draw()
		return FALSE
	return TRUE

/obj/map_metadata/broadside/proc/end_broadside_draw()
	ticker.finished = TRUE
	next_win = -1
	current_win_condition = no_winner
	win_condition.hash = 0
	last_win_condition = win_condition.hash
	win_condition_spam_check = TRUE
	to_chat(world, "<font size = 4 color='yellow'><span class = 'notice'>Night falls on the sea, and both ships are still afloat. Nobody wins.</span></font>")
	show_global_battle_report(null)

#undef BROADSIDE_PACE
#undef BROADSIDE_SUNK_SHARE
#undef BROADSIDE_CAPTURE_TIME
#undef BROADSIDE_TIME_LIMIT
