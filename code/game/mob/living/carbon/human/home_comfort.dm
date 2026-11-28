// Home comfort: the roofed room a character sleeps in is judged when they fall
// asleep. Each kind of comfort counts once, so variety and upkeep matter, not
// piles of furniture. The tier is saved with the body beside sleep_comfort and
// counts from waking until the next sleep, the same way the bed does.
//
// It pays three ways (docs/home-comfort.md): it replaces the plain "roof over
// your head" part of the resting mood, a Fine or Splendid home lifts the
// resting cap a little (still short of Excellent), and waking in a Comfortable
// or better home leaves the character well rested for a while.

#define HOME_ROOM_LIMIT 150     // tiles a room survey looks at before it stops
#define HOME_TIER_BARE 0
#define HOME_TIER_COSY 1
#define HOME_TIER_COMFORTABLE 2
#define HOME_TIER_FINE 3
#define HOME_TIER_SPLENDID 4
#define HOME_FLOOR_SHARE 0.5    // share of the room that must be covered
#define HOME_MESS_ALLOWED 2     // stains and rubbish a clean room may still have
#define HOME_TIDY_LOOSE 5       // loose things a tidy room may have on its floor
#define HOME_SOUND_SHARE 0.5    // walls below this share of health are cracked
#define HOME_RESTED_STAMINA 0.25 // extra stamina recovery while well rested
#define HOME_RESTED_HUNGER 0.85  // hunger and thirst rate while well rested
#define HOME_JUDGE_GAP 50       // deciseconds between Judge This Room uses

// Comfort categories, in the order they are listed to players.
var/list/home_comfort_categories = list(
	"floor" = "a covered floor",
	"walls" = "finished walls",
	"light" = "a light",
	"furniture" = "a bed, a seat and a table",
	"art" = "a work of art",
	"plants" = "a living plant",
	"name" = "a named house (a sign)",
	"wash" = "a place to wash",
	"clean" = "a clean room",
	"tidy" = "a tidy room (a chest or basket, and no more than 5 things on the floor)",
	"sound" = "sound walls",
	"upstairs" = "a quiet bedroom upstairs (no stove or workbench in it)")

/proc/home_tier_for(points)
	if (points >= 9)
		return HOME_TIER_SPLENDID
	if (points >= 7)
		return HOME_TIER_FINE
	if (points >= 5)
		return HOME_TIER_COMFORTABLE
	if (points >= 3)
		return HOME_TIER_COSY
	return HOME_TIER_BARE

/proc/home_tier_name(tier)
	switch (tier)
		if (HOME_TIER_SPLENDID)
			return "splendid"
		if (HOME_TIER_FINE)
			return "fine"
		if (HOME_TIER_COMFORTABLE)
			return "comfortable"
		if (HOME_TIER_COSY)
			return "cosy"
	return "bare"

// The resting-mood part a home gives; a bare room is just a roof.
/proc/home_tier_mood(tier)
	switch (tier)
		if (HOME_TIER_SPLENDID)
			return 8
		if (HOME_TIER_FINE)
			return 6
		if (HOME_TIER_COMFORTABLE)
			return 5
		if (HOME_TIER_COSY)
			return 4
	return 0

// How far a home lifts the resting cap. MOOD_REST_MAX + 4 stays below 80, so
// living conditions alone never reach an excellent mood.
/proc/home_tier_cap_bonus(tier)
	switch (tier)
		if (HOME_TIER_SPLENDID)
			return 4
		if (HOME_TIER_FINE)
			return 2
	return 0

// How long waking in a home leaves a character well rested (deciseconds).
/proc/home_tier_rested_time(tier)
	switch (tier)
		if (HOME_TIER_SPLENDID)
			return 36000
		if (HOME_TIER_FINE)
			return 27000
		if (HOME_TIER_COMFORTABLE)
			return 18000
	return 0

// A tile counts as part of a room while it is roofed.
/proc/home_turf_inside(turf/T)
	if (!T)
		return FALSE
	var/area/A = get_area(T)
	return A && A.location == AREA_INSIDE

// What bounds a room: a solid turf, a built wall, a door, a window or a closed curtain.
/proc/home_turf_bounds_room(turf/T)
	if (!T)
		return TRUE
	if (T.density)
		return TRUE
	for (var/obj/O in T)
		if (istype(O, /obj/covers))
			var/obj/covers/C = O
			if (C.wall)
				return TRUE
		else if (istype(O, /obj/structure/simple_door) || istype(O, /obj/structure/window_frame) || istype(O, /obj/structure/window))
			return TRUE
		else if (istype(O, /obj/structure/curtain) && O.opacity)
			return TRUE
	return FALSE

// The roofed room around a tile: list("turfs" = list, "walls" = list).
/proc/home_room_survey(turf/start)
	var/list/turfs = list()
	var/list/walls = list()
	if (!home_turf_inside(start) || home_turf_bounds_room(start))
		return list("turfs" = turfs, "walls" = walls)
	var/list/seen = list()
	seen[start] = TRUE
	turfs += start
	var/i = 1
	while (i <= turfs.len && turfs.len < HOME_ROOM_LIMIT)
		var/turf/T = turfs[i]
		i++
		for (var/dir in cardinal)
			var/turf/N = get_step(T, dir)
			if (!N || seen[N])
				continue
			seen[N] = TRUE
			if (home_turf_bounds_room(N))
				walls += N
			else if (home_turf_inside(N))
				turfs += N
				if (turfs.len >= HOME_ROOM_LIMIT)
					break
	return list("turfs" = turfs, "walls" = walls)

// Whether a wall face has been finished (whitewashed, plastered, painted).
/obj/covers/proc/home_finished()
	return FALSE

// Whether a floor tile is covered by something laid down on purpose.
/proc/home_floor_covered(turf/T)
	if (istype(T, /turf/floor/carpet) || istype(T, /turf/floor/wood) || woven_rug_covers(T) || pelt_rug_covers(T))
		return TRUE
	for (var/obj/covers/C in T)
		if (!C.wall)
			return TRUE
	return FALSE

/proc/home_is_light(atom/movable/A)
	if (A.light_range > 0)
		return TRUE
	return istype(A, /obj/structure/lamp) || istype(A, /obj/structure/brazier) || istype(A, /obj/structure/torch_stand) || istype(A, /obj/structure/oven/fireplace) || istype(A, /obj/item/flashlight)

/proc/home_is_plant(atom/movable/A)
	if (istype(A, /obj/structure/plant_pot))
		var/obj/structure/plant_pot/P = A
		return P.filled
	return istype(A, /obj/structure/farming/plant) || istype(A, /obj/structure/wild/flowers)

/proc/home_is_named_sign(atom/movable/A)
	return istype(A, /obj/structure/sign/custom) && A.name != "sign"

// Judges the room around a tile: list("points", "tier", "have", "missing", "tiles").
// A stove, forge or workbench: it belongs in the kitchen or the workshop, not the bedroom.
/proc/home_is_work_station(atom/movable/A)
	if (istype(A, /obj/structure/oven))
		return !istype(A, /obj/structure/oven/fireplace)
	return istype(A, /obj/structure/anvil) || istype(A, /obj/structure/loom) || istype(A, /obj/structure/furnace) || istype(A, /obj/structure/dehydrator) || istype(A, /obj/structure/repair/workbench) || istype(A, /obj/structure/component_workbench)

/proc/home_comfort_judge(turf/start)
	var/list/room = home_room_survey(start)
	var/list/turfs = room["turfs"]
	var/list/walls = room["walls"]
	var/list/have = list()
	if (turfs.len)
		var/covered = 0
		var/mess = 0
		var/foul = FALSE
		var/bed = FALSE
		var/seat = FALSE
		var/table = FALSE
		var/container = FALSE
		var/loose = 0
		var/work = FALSE
		for (var/turf/T in turfs)
			if (home_floor_covered(T))
				covered++
			for (var/atom/movable/A in T)
				if (istype(A, /mob))
					continue
				if (istype(A, /obj/effect/decal/cleanable) || istype(A, /obj/item/trash))
					mess++
				else if (istype(A, /obj/structure/bed/chair) || istype(A, /obj/item/weapon/stool))
					seat = TRUE
				else if (istype(A, /obj/structure/bed) && !istype(A, /obj/structure/bed/bedroll))
					bed = TRUE
				else if (istype(A, /obj/structure/table))
					table = TRUE
				if (home_is_container(A))
					container = TRUE
				else if (home_is_loose_thing(A))
					loose++
				if (home_is_light(A))
					have["light"] = TRUE
				if (isobj(A) && mood_is_art(A))
					have["art"] = TRUE
				if (home_is_plant(A))
					have["plants"] = TRUE
				if (home_is_named_sign(A))
					have["name"] = TRUE
				if (home_is_wash_place(A))
					have["wash"] = TRUE
				if (home_is_foul(A))
					foul = TRUE
				if (home_is_work_station(A))
					work = TRUE
		if (covered >= turfs.len * HOME_FLOOR_SHARE)
			have["floor"] = TRUE
		if (bed && seat && table)
			have["furniture"] = TRUE
		// A bedroom on a storey of its own, away from the kitchen and the workshop.
		if (bed && !work && turf_is_above_ground(start))
			have["upstairs"] = TRUE
		if (mess <= HOME_MESS_ALLOWED && !foul)
			have["clean"] = TRUE
		if (container && loose <= HOME_TIDY_LOOSE)
			have["tidy"] = TRUE
		var/built_walls = 0
		var/finished_walls = 0
		var/sound = TRUE
		for (var/turf/W in walls)
			for (var/obj/O in W)
				if (home_is_named_sign(O))
					have["name"] = TRUE
				else if (mood_is_art(O))
					have["art"] = TRUE
				if (!istype(O, /obj/covers))
					continue
				var/obj/covers/C = O
				if (!C.wall)
					continue
				built_walls++
				if (C.home_finished())
					finished_walls++
				if (C.maxhealth > 0 && C.health < C.maxhealth * HOME_SOUND_SHARE)
					sound = FALSE
		if (built_walls && finished_walls >= built_walls * HOME_FLOOR_SHARE)
			have["walls"] = TRUE
		if (sound)
			have["sound"] = TRUE
	var/list/missing = list()
	for (var/category in home_comfort_categories)
		if (!have[category])
			missing += home_comfort_categories[category]
	var/points = have.len
	return list("points" = points, "tier" = turfs.len ? home_tier_for(points) : HOME_TIER_BARE, "have" = have, "missing" = missing, "tiles" = turfs.len)

// Saved with the body: the tier of the home last slept in.
/mob/living/human/var/home_comfort = HOME_TIER_BARE
/mob/living/human/var/tmp/home_slept_judged = FALSE // judged during this sleep
/mob/living/human/var/tmp/list/home_slept_missing    // what that room lacked
/mob/living/human/var/tmp/well_rested_until = 0
/mob/living/human/var/tmp/home_judge_next = 0

/mob/living/human/persistence_runtime_var(key)
	return key == "home_slept_judged" || key == "home_slept_missing" || key == "well_rested_until" || key == "home_judge_next" || ..()

// Called while asleep and on waking from refresh_mood_rest().
/mob/living/human/proc/home_comfort_sleep_tick()
	if (home_slept_judged)
		return
	home_slept_judged = TRUE
	var/list/judged = home_comfort_judge(get_turf(src))
	home_comfort = judged["tier"]
	home_slept_missing = judged["missing"]

/mob/living/human/proc/home_comfort_wake()
	if (!home_slept_judged)
		return
	home_slept_judged = FALSE
	if (!mood_needs_mode())
		return
	var/rested = home_tier_rested_time(home_comfort)
	if (rested)
		well_rested_until = world.time + rested
	if (!client || home_comfort == HOME_TIER_BARE)
		return
	var/text = "You slept in a [home_tier_name(home_comfort)] home"
	if (rested)
		text += " and wake well rested"
	text += "."
	if (home_comfort < HOME_TIER_SPLENDID && islist(home_slept_missing) && home_slept_missing.len)
		text += " It would be finer with [english_list(home_slept_missing)]."
	to_chat(src, "<span class='info'>[text]</span>")

/mob/living/human/proc/home_well_rested()
	return well_rested_until && world.time < well_rested_until

/mob/living/human/proc/home_rest_cap_bonus()
	if (!mood_needs_mode())
		return 0
	return home_tier_cap_bonus(home_comfort)

/mob/living/human/proc/home_rest_hunger_mult()
	return home_well_rested() ? HOME_RESTED_HUNGER : 1

/mob/living/human/proc/home_recover_stamina()
	if (!home_well_rested() || !islist(stats["stamina"]))
		return
	var/cap = diet_stamina_cap()
	var/current = stats["stamina"][1]
	if (current >= cap || current <= 0)
		return
	stats["stamina"][1] = clamp(current + stats["stamina"][2] * 0.02 * diet_recovery_factor() * HOME_RESTED_STAMINA, 0, cap)

/mob/living/human/verb/judge_room()
	set name = "Judge This Room"
	set category = "IC"
	set desc = "See how comfortable the room you stand in would be to sleep in, and what it lacks."
	if (stat != CONSCIOUS)
		return
	if (world.time < home_judge_next)
		to_chat(src, "<span class='warning'>You are still looking around.</span>")
		return
	home_judge_next = world.time + HOME_JUDGE_GAP
	var/list/judged = home_comfort_judge(get_turf(src))
	if (!judged["tiles"])
		to_chat(src, "<span class='warning'>You need to be under a roof, inside a room.</span>")
		return
	var/list/have = list()
	for (var/category in home_comfort_categories)
		if (category in judged["have"])
			have += home_comfort_categories[category]
	var/list/missing = judged["missing"]
	var/text = "This room would make a [home_tier_name(judged["tier"])] home ([judged["points"]] of [home_comfort_categories.len])."
	if (have.len)
		text += "<br>It has [english_list(have)]."
	if (missing.len)
		text += "<br>It lacks [english_list(missing)]."
	if (map?.book_research_enabled())
		var/capacity = rested_research_room_capacity(judged)
		if (capacity)
			text += "<br>Sleeping here can fill your rested research bank to [capacity] points."
		else
			text += "<br>Furnish this room with a proper bed, a seat and a table before sleeping here to earn rested research points."
		text += " You have [rested_research_points] banked."
	var/warmth = building_room_warmth_text(building_room_at(get_turf(src)))
	if (warmth)
		text += "<br>[warmth]"
	to_chat(src, "<span class='info'>[text]</span>")

#undef HOME_ROOM_LIMIT
#undef HOME_FLOOR_SHARE
#undef HOME_MESS_ALLOWED
#undef HOME_SOUND_SHARE
#undef HOME_RESTED_STAMINA
#undef HOME_RESTED_HUNGER
#undef HOME_JUDGE_GAP
