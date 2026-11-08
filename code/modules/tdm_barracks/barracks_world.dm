// The Barracks map (maps/special/tdm_barracks.dmm): an always-playing world
// with ranges, practice yards, arenas, and the boards and gate that link it to
// the TDM battle world (barracks.dm). Layout: docs/tdm-barracks.md.

/obj/map_metadata/tdm_barracks
	ID = MAP_TDM_BARRACKS
	title = "Barracks"
	description = "Wait for the next battle, practise on the ranges and arenas, and check the leaderboards."
	lobby_icon = "icons/lobby/football.png"
	respawn_delay = 0
	no_winner = "The Barracks never closes."
	faction_organization = list(CIVILIAN)
	roundend_condition_sides = list(list(CIVILIAN) = /area/caribbean/barracks)
	age = "2013"
	ordinal_age = 8
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "barracks"
	mission_start_message = "<big><b>Welcome to the Barracks.</b> Practise here while you wait for the next battle.</big>"
	ambience = list("sound/ambience/football.ogg")
	faction1 = CIVILIAN
	is_singlefaction = TRUE
	gamemode_vote = FALSE
	gamemode = "Barracks"
	no_time_of_day_cycle = TRUE
	valid_weather_types = list(WEATHER_NONE)
	has_hunger = FALSE
	research_active = FALSE

/obj/map_metadata/tdm_barracks/cross_message(faction)
	return ""

/obj/map_metadata/tdm_barracks/reverse_cross_message(faction)
	return ""

// The Barracks round never ends.
/obj/map_metadata/tdm_barracks/update_win_condition()
	return TRUE

/datum/job/civilian/barracks_recruit
	title = "Recruit"
	en_meaning = ""
	rank_abbreviation = ""
	spawn_location = "JoinLateCivA"
	min_positions = 200
	max_positions = 200
	selection_color = "#4A5D23"
	allowed_maps = list(MAP_TDM_BARRACKS)

/datum/job/civilian/barracks_recruit/equip(var/mob/living/human/H)
	if (!H)
		return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/under/us_uni/us_camo_woodland(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/blackboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/stack/medical/bruise_pack(H), slot_l_store)
	H.civilization = "Barracks"
	H.add_note("Barracks", "You are in the Barracks. Pick up practice gear in the armory, try the ranges and yards, and use the deployment gate (or Barracks > Join Battle) when a battle forms. Deaths here do not count: you are back in the arrival hall at once.")
	// The arrival hall is safe; areas set this as players move (barracks_area_entered).
	H.status_flags |= GODMODE
	..()
	return TRUE

// -- areas: safe ones turn damage off, combat ones turn it on -------------------

/area/caribbean/barracks
	name = "Barracks"
	icon_state = "green1"
	location = AREA_INSIDE
	climate = "temperate"
	base_turf = /turf/floor/plating/concrete
	artillery_integrity = INFINITY
	ambience = list("sound/ambience/football.ogg")
	// Always lit: no lighting overlays, so no lighting RAM, and nobody waits in the dark.
	dynamic_lighting = FALSE
	var/barracks_safe = TRUE

/area/caribbean/barracks/range
	name = "Barracks Firing Line"
	icon_state = "blue1"

/area/caribbean/barracks/range/lanes
	name = "Barracks Range Lanes"
	icon_state = "red1"
	barracks_safe = FALSE

/area/caribbean/barracks/combat
	name = "Barracks Practice Yard"
	icon_state = "red2"
	barracks_safe = FALSE

/area/caribbean/barracks/combat/team1
	name = "Barracks Red Ready Room"

/area/caribbean/barracks/combat/team2
	name = "Barracks Blue Ready Room"

/area/caribbean/barracks/Entered(atom/movable/A)
	..()
	barracks_area_entered(A, src)

/proc/barracks_area_entered(atom/movable/A, area/caribbean/barracks/B)
	if (!ishuman(A) || !istype(B) || !map || map.ID != MAP_TDM_BARRACKS)
		return
	var/mob/living/human/H = A
	if (B.barracks_safe)
		H.status_flags |= GODMODE
	else
		H.status_flags &= ~GODMODE

// -- the deployment gate, status board and leaderboards --------------------------

/obj/structure/barracks
	icon = 'icons/obj/decals.dmi'
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/barracks/ex_act()
	return

/obj/structure/barracks/bullet_act()
	return

/obj/structure/barracks/deploy_gate
	name = "deployment gate"
	desc = "The way to the battle. Click it to join the battle, or to switch auto-join."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "metal"

/obj/structure/barracks/deploy_gate/examine(mob/user)
	..()
	if (user && tdm_barracks_active())
		to_chat(user, SPAN_NOTICE(tdm_barracks.summary_line()))

/obj/structure/barracks/deploy_gate/attack_hand(mob/user)
	if (!user || !user.client)
		return
	if (!tdm_barracks_active())
		to_chat(user, SPAN_WARNING("The gate leads nowhere: this server has no battle world."))
		return
	var/choice = WWinput(user, "[tdm_barracks.summary_line()].", "Deployment Gate", "Join the battle", list("Join the battle", "Switch auto-join", "Battle status", "Stay"))
	if (!user || !user.client)
		return
	switch (choice)
		if ("Join the battle")
			tdm_barracks.join(user.client)
		if ("Switch auto-join")
			tdm_barracks.toggle_auto(user.client)
		if ("Battle status")
			tdm_barracks.show_status(user.client)

/obj/structure/barracks/deploy_gate/Bumped(atom/movable/A)
	if (ismob(A))
		attack_hand(A)

/obj/structure/barracks/status_board
	name = "battle status board"
	desc = "Live news from the battle. Click it for the whole picture."
	icon = 'icons/obj/decals.dmi'
	icon_state = "map_board"
	density = FALSE

/obj/structure/barracks/status_board/examine(mob/user)
	..()
	if (user && tdm_barracks_active())
		to_chat(user, SPAN_NOTICE(tdm_barracks.summary_line()))

/obj/structure/barracks/status_board/attack_hand(mob/user)
	if (user && user.client && tdm_barracks_active())
		tdm_barracks.show_status(user.client)

/obj/structure/barracks/leaderboard
	name = "leaderboard"
	desc = "The best fighters of the battles. Click it to read it."
	icon = 'icons/obj/decals.dmi'
	icon_state = "goldenplaque"
	density = FALSE
	var/board = "top"

/obj/structure/barracks/leaderboard/record
	name = "service record"
	desc = "Your own battles. Click it to read them."
	board = "record"

/obj/structure/barracks/leaderboard/history
	name = "recent battles"
	desc = "The last battles fought. Click it to read them."
	board = "history"

/obj/structure/barracks/leaderboard/attack_hand(mob/user)
	if (!user || !user.client)
		return
	if (!tdm_barracks_active())
		to_chat(user, SPAN_NOTICE("The board is blank: this server has no battle world."))
		return
	switch (board)
		if ("record")
			tdm_barracks.show_stats(user.client)
		if ("history")
			tdm_barracks.show_status(user.client)
		else
			tdm_barracks.show_board(user.client)

// The practice rooms build themselves on a temporary level from the lobby
// panel (Practice Room); this console only points the way.
/obj/structure/barracks/practice_console
	name = "training rooms console"
	desc = "Guided practice rooms for new players."
	icon = 'icons/obj/computers.dmi'
	icon_state = "computer"

/obj/structure/barracks/practice_console/attack_hand(mob/user)
	if (user)
		to_chat(user, SPAN_NOTICE("The guided training rooms open from the lobby panel: use OOC > Respawn or wait for your next respawn, then pick <b>Practice Room</b>."))

// -- the quartermaster: one kit per battle era ------------------------------------

/obj/structure/barracks/kit_locker
	name = "kit locker"
	desc = "Hands out a practice kit."
	icon = 'icons/obj/closet.dmi'
	icon_state = "cabinet_closed"
	var/era = "2013"
	var/list/kit = list(/obj/item/weapon/gun/projectile/submachinegun/m16, /obj/item/ammo_magazine/m16, /obj/item/ammo_magazine/m16, /obj/item/ammo_magazine/m16)
	var/list/last_use = list()
	var/football_team = null // pitch lockers put the player on a side, so tackles and passes know teammates

/obj/structure/barracks/kit_locker/New()
	..()
	name = "[era] kit locker"
	desc = "Hands out a practice kit for [era] battles."

/obj/structure/barracks/kit_locker/era1713
	era = "1713"
	kit = list(/obj/item/weapon/gun/projectile/flintlock/brownbess, /obj/item/ammo_casing/musketball, /obj/item/ammo_casing/musketball, /obj/item/ammo_casing/musketball, /obj/item/ammo_casing/musketball, /obj/item/ammo_casing/musketball)

/obj/structure/barracks/kit_locker/era1873
	era = "1873"
	kit = list(/obj/item/weapon/gun/projectile/revolver/peacemaker, /obj/item/ammo_magazine/c45, /obj/item/ammo_magazine/c45)

/obj/structure/barracks/kit_locker/era1943
	era = "1943"
	kit = list(/obj/item/weapon/gun/projectile/boltaction/mosin, /obj/item/ammo_magazine/mosin, /obj/item/ammo_magazine/mosin, /obj/item/ammo_magazine/mosin)

/obj/structure/barracks/kit_locker/era1969
	era = "1969"
	kit = list(/obj/item/weapon/gun/projectile/submachinegun/ak47, /obj/item/ammo_magazine/ak47, /obj/item/ammo_magazine/ak47, /obj/item/ammo_magazine/ak47)

/obj/structure/barracks/kit_locker/attack_hand(mob/living/human/user)
	if (!istype(user))
		return
	if (last_use[user.ckey] && world.time < last_use[user.ckey] + 300)
		to_chat(user, SPAN_WARNING("The quartermaster just gave you a kit. Wait a little."))
		return
	last_use[user.ckey] = world.time
	if (football_team)
		user.civilization = football_team
	for (var/path in kit)
		var/obj/item/I = new path(get_turf(src))
		user.put_in_hands(I)
	user.visible_message(SPAN_NOTICE("[user] takes a [era] kit from \the [src]."), SPAN_NOTICE("You take a [era] kit. What does not fit in your hands is on the floor."))

// -- ranges, yards and course -----------------------------------------------------

// A range target that tells the shooter the distance and their streak.
/obj/structure/practice_dummy/target/human/indestructible/scored
	var/list/streaks = list()

/obj/structure/practice_dummy/target/human/indestructible/scored/bullet_act(obj/item/projectile/proj)
	. = ..()
	if (!proj || !ishuman(proj.firer))
		return
	var/mob/living/human/H = proj.firer
	if (!H.ckey)
		return
	streaks[H.ckey] = (streaks[H.ckey] || 0) + 1
	to_chat(H, SPAN_NOTICE("Hit at [get_dist(H, src)] tiles. Streak: [streaks[H.ckey]]."))

// Re-creates its object on its tile a while after it is gone (dummies, crates).
/obj/effect/landmark/barracks_respawner
	name = "barracks respawner"
	var/spawn_type = /obj/structure/practice_dummy
	var/delay = 600
	var/obj/current = null

/obj/effect/landmark/barracks_respawner/New()
	..()
	watch()

/obj/effect/landmark/barracks_respawner/proc/watch()
	set waitfor = FALSE
	sleep(10)
	while (src && loc)
		if (!current || QDELETED(current) || current.loc != loc)
			var/found = locate(spawn_type) in loc
			if (found)
				current = found
			else
				sleep(delay)
				if (!src || !loc)
					return
				if (!locate(spawn_type) in loc)
					current = new spawn_type(loc)
		sleep(100)

/obj/effect/landmark/barracks_respawner/grenades
	spawn_type = /obj/structure/closet/crate/grenades
	delay = 1200

/obj/effect/landmark/barracks_respawner/mortar_shells
	spawn_type = /obj/structure/closet/crate/ww2/mortar_shells
	delay = 1200

// Obstacle course timing pads: start on one, finish on the other.
/mob/living/human/var/barracks_course_start = 0
var/global/barracks_course_best = 0
var/global/barracks_course_best_key = null

/obj/effect/step_trigger/barracks_course
	name = "course pad"
	var/role = "start"

/obj/effect/step_trigger/barracks_course/finish
	role = "finish"

/obj/effect/step_trigger/barracks_course/Trigger(atom/movable/A)
	if (!ishuman(A))
		return FALSE
	var/mob/living/human/H = A
	if (role == "start")
		if (!H.barracks_course_start || world.time - H.barracks_course_start > 50)
			H.barracks_course_start = world.time
			to_chat(H, SPAN_NOTICE("<b>Go!</b> The obstacle course clock is running."))
		return TRUE
	if (!H.barracks_course_start)
		return FALSE
	var/seconds = round((world.time - H.barracks_course_start) / 10, 0.1)
	H.barracks_course_start = 0
	var/record = !barracks_course_best || seconds < barracks_course_best
	to_chat(H, SPAN_NOTICE("You finish the obstacle course in <b>[seconds]</b> seconds.[record ? " That is the best time today!" : " Today's best: [barracks_course_best] s by [barracks_course_best_key]."]"))
	if (record)
		barracks_course_best = seconds
		barracks_course_best_key = H.key
		for (var/mob/living/human/M in range(12, src))
			if (M != H)
				to_chat(M, SPAN_NOTICE("[H.real_name] sets the course record: [seconds] seconds."))
	return TRUE

// -- deaths cost nothing: patched up and back in the arrival hall ------------------

/hook/death/proc/barracks_death(mob/living/human/H, gibbed)
	if (istype(H) && !gibbed && map && map.ID == MAP_TDM_BARRACKS && H.ckey)
		barracks_return(H)
	return TRUE

/proc/barracks_return(mob/living/human/H)
	set waitfor = FALSE
	sleep(30)
	if (!H || QDELETED(H) || H.stat != DEAD || !H.ckey)
		return
	var/list/spots = latejoin_turfs["JoinLateCivA"]
	var/turf/T = (islist(spots) && spots.len) ? pick(spots) : null
	if (!T)
		return
	H.revive()
	H.forceMove(T)
	H.status_flags |= GODMODE
	to_chat(H, SPAN_NOTICE("You are patched up and back in the arrival hall."))

// -- football on the parade ground ---------------------------------------------------
// The ball, dribbling, passing and kicking are the football map's own
// (weapons/football.dm, football.dm); dribbling and kicking need football boots, which the
// pitch lockers hand out. Goals here keep a pitch score instead of a match.

var/global/list/barracks_football_score = list("Red" = 0, "Blue" = 0)

// On the football map the kit is locked on and everyone plays. Elsewhere (the
// Barracks pitch) the boots and jersey come off like any clothes, and only a
// player in football boots on the pitch takes or keeps the ball, so nobody
// walks off with it stuck to their feet or loses their clicks to kicking.
/proc/barracks_can_dribble(mob/living/human/H)
	if (istype(map, /obj/map_metadata/football))
		return TRUE
	return istype(H) && istype(H.shoes, /obj/item/clothing/shoes/football) && istype(get_area(H), /area/caribbean/barracks/pitch)

/proc/barracks_kit_unequip(obj/item/I, mob/M, slot, disable_warning)
	if (!slot || !M || !I.canremove)
		return FALSE
	return M.slot_is_accessible(slot, I, disable_warning ? null : M)

/obj/item/clothing/shoes/football/mob_can_unequip(mob/M, slot, disable_warning = FALSE)
	if (istype(map, /obj/map_metadata/football))
		return ..()
	return barracks_kit_unequip(src, M, slot, disable_warning)

/obj/item/clothing/under/football/mob_can_unequip(mob/M, slot, disable_warning = FALSE)
	if (istype(map, /obj/map_metadata/football))
		return ..()
	return barracks_kit_unequip(src, M, slot, disable_warning)

/obj/item/football/Crossed(mob/living/human/user)
	if (ishuman(user) && !barracks_can_dribble(user))
		return
	return ..()

/obj/item/football/update_movement()
	if (owner && !barracks_can_dribble(owner))
		var/mob/living/human/H = owner
		H.football = null
		owner = null
		last_owner = H
		return
	return ..()

/mob/living/human/football_bump(atom/movable/AM)
	if (istype(AM, /obj/item/football) && !barracks_can_dribble(src))
		return
	return ..()

/mob/living/human/football_hitby(obj/item/football/FB)
	if (!barracks_can_dribble(src))
		return
	return ..()

/area/caribbean/barracks/pitch
	name = "Barracks Football Pitch"
	icon_state = "green1"

/obj/effect/landmark/barracks_ball_spot
	name = "barracks centre spot"

/obj/effect/step_trigger/goal/barracks
	name = "goal"

// The side that scores when the ball crosses this line.
/obj/effect/step_trigger/goal/barracks/red
	name = "blue goal"
	team = "Red"

/obj/effect/step_trigger/goal/barracks/blue
	name = "red goal"
	team = "Blue"

/obj/effect/step_trigger/goal/barracks/Trigger(atom/movable/A)
	if (!istype(A, /obj/item/football) || !team)
		return FALSE
	var/obj/item/football/FB = A
	var/mob/living/human/scorer = FB.last_owner
	barracks_football_score[team] = (barracks_football_score[team] || 0) + 1
	var/line = "<font size=3 color='orange'><b>GOAL!</b> [scorer ? "[scorer.real_name] scores" : "A goal"] for <b>[team]</b>. Red [barracks_football_score["Red"]] - [barracks_football_score["Blue"]] Blue.</font>"
	for (var/mob/M in range(20, src))
		if (M.client)
			to_chat(M, line)
	playsound(loc, 'sound/effects/football_whistle.ogg', 100, 1)
	barracks_football_reset(FB)
	return TRUE

/proc/barracks_football_reset(obj/item/football/FB)
	if (!FB)
		return
	if (FB.owner)
		FB.owner.football = null
	FB.owner = null
	FB.last_owner = null
	var/obj/effect/landmark/barracks_ball_spot/spot = locate() in landmarks_list
	if (spot)
		FB.forceMove(get_turf(spot))

/obj/structure/barracks/football_board
	name = "pitch scoreboard"
	desc = "The score of the kickabout on the parade ground."
	icon = 'icons/obj/decals.dmi'
	icon_state = "map_board"
	density = FALSE

/obj/structure/barracks/football_board/examine(mob/user)
	..()
	if (user)
		to_chat(user, SPAN_NOTICE("Red [barracks_football_score["Red"]] - [barracks_football_score["Blue"]] Blue."))

/obj/structure/barracks/football_board/attack_hand(mob/user)
	if (!user || !user.client)
		return
	var/choice = WWinput(user, "Red [barracks_football_score["Red"]] - [barracks_football_score["Blue"]] Blue.", "Pitch Scoreboard", "Close", list("Close", "Reset the score", "Ball to the centre spot"))
	switch (choice)
		if ("Reset the score")
			barracks_football_score = list("Red" = 0, "Blue" = 0)
			for (var/mob/M in range(20, src))
				if (M.client)
					to_chat(M, SPAN_NOTICE("[user] resets the pitch score: Red 0 - 0 Blue."))
		if ("Ball to the centre spot")
			for (var/obj/item/football/FB in range(30, src))
				barracks_football_reset(FB)
				break

/obj/structure/barracks/kit_locker/football_red
	era = "Red football"
	football_team = "Red"
	kit = list(/obj/item/clothing/shoes/football, /obj/item/clothing/under/football/red)

/obj/structure/barracks/kit_locker/football_blue
	era = "Blue football"
	football_team = "Blue"
	kit = list(/obj/item/clothing/shoes/football, /obj/item/clothing/under/football/blue)
