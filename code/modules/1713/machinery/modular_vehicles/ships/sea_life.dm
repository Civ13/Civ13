// Sea life on the seabed (ocean phase 4).
//
// Animals of the sea layer (sea_layer.dm) live only in open sea-layer water:
// they never enter a boat's hull, never leave the water and keep to the
// depth zones (seabed.dm) their kind lives in. They share one small AI:
//
// - Senses: divers out in the water, lamps (a lit helmet or hand lamp, a
//   submarine's floodlights) and noise (a sonar ping, sea_noise()).
// - Each kind picks a step from what it senses: shoals scatter and regroup,
//   the kelp turtle grazes and flees when hurt, the reef eel waits in a rock
//   crevice and lunges at divers who swim close, the drift jelly drifts and
//   stings whatever it touches.
//
// They spawn through the ecology spawner (ecology_spawning.dm) with their
// own cap (map.sea_life_cap), out of every player's sight, once the depth
// zones are known. Like land wildlife they rest far from players and hold
// still while nobody is connected.

// Seconds a frightened animal keeps fleeing.
#define SEA_FLEE_TIME (4 SECONDS)
// How long a noise is heard, and how many are remembered.
#define SEA_NOISE_LIFE (6 SECONDS)
#define SEA_NOISES_MAX 32
// Spawning: animals placed per ecology cycle, and site attempts per species.
#define SEA_SPAWN_BUDGET 12
#define SEA_SPAWN_ATTEMPTS 24
#define SEA_SPAWN_VIEW_MARGIN 12
#define SEA_HERD_RANGE 2

/obj/map_metadata/var/sea_life_cap = 120

// Code changes take effect on load instead of a saved copy.
/obj/map_metadata/persistence_runtime_var(key)
	return key == "sea_life_cap" || ..(key)

// ---- Noise ----

// Recent noises in the water: list(x, y, z, range, world.time).
var/global/list/sea_noises = list()

// Something loud happened at T: animals within range hear it for a few seconds.
/proc/sea_noise(turf/T, range)
	T = get_turf(T)
	if (!T || range <= 0)
		return
	var/list/keep = list()
	for (var/list/N in sea_noises)
		if (world.time - N[5] < SEA_NOISE_LIFE)
			keep[++keep.len] = N
	keep[++keep.len] = list(T.x, T.y, T.z, range, world.time)
	while (keep.len > SEA_NOISES_MAX)
		keep.Cut(1, 2)
	sea_noises = keep

// The nearest recent noise that reaches T, as a turf, or null.
/proc/sea_noise_heard(turf/T)
	if (!T)
		return null
	var/best = 0
	var/turf/found = null
	for (var/list/N in sea_noises)
		if (N[3] != T.z || world.time - N[5] >= SEA_NOISE_LIFE)
			continue
		var/dist = max(abs(N[1] - T.x), abs(N[2] - T.y))
		if (dist > N[4])
			continue
		if (!found || dist < best)
			best = dist
			found = locate(N[1], N[2], N[3])
	return found

// ---- Shared senses ----

// A person out in the water (not aboard a boat).
/proc/sea_diver(mob/living/M)
	if (!istype(M) || M.stat == DEAD || istype(M, /mob/living/simple_animal/sea))
		return FALSE
	var/turf/T = get_turf(M)
	return sea_layer_cell(T) && !T.iscovered()

// TRUE when M carries or wears a lit lamp.
/proc/sea_lamp_lit(mob/living/M)
	if (M.light_range > 0)
		return TRUE
	for (var/obj/item/I in M.contents)
		if (I.light_range > 0)
			return TRUE
	return FALSE

// ---- The animal ----

/mob/living/simple_animal/sea
	name = "sea animal"
	icon = 'icons/mob/sea_life.dmi'
	faction = "sea"
	behaviour = "sea"
	wander = FALSE
	starves = FALSE
	minbodytemp = 0
	maxbodytemp = 400
	speak_chance = 0
	has_fat = FALSE
	response_help = "strokes"
	response_disarm = "pushes aside"
	response_harm = "hits"
	stop_automated_movement_when_pulled = FALSE
	// Depth zones it lives in (SEA_ZONE_*).
	var/zone_min = SEA_ZONE_SHELF
	var/zone_max = SEA_ZONE_ABYSS
	// Ticks for one tile of swimming, and life ticks between steps when idle.
	var/swim_interval = 8
	var/idle_every = 1
	// What butchering gives, and how many.
	var/sea_meat = /obj/item/weapon/reagent_containers/food/snacks/rawfish
	var/sea_meat_amount = 1
	// Dead art when it lives in another icon file (the shoals).
	var/dead_icon = null
	var/tmp/swim_dir = 0
	var/tmp/idle_ticks = 0
	var/tmp/flee_until = 0
	var/tmp/atom/flee_from = null
	var/tmp/turf/home_hint = null

/mob/living/simple_animal/sea/New()
	..()
	swim_dir = pick(alldirs)

/mob/living/simple_animal/sea/persistence_runtime_var(key)
	return (key in list("swim_dir", "idle_ticks", "flee_until", "flee_from", "home_hint")) || ..(key)

/mob/living/simple_animal/sea/can_walk_seabed()
	return TRUE

/mob/living/simple_animal/sea/death(gibbed, deathmessage = "goes still.")
	flee_from = null
	if (dead_icon)
		icon = dead_icon
	return ..(gibbed, deathmessage)

// Butchering: its own catch instead of land meat, bones and hide.
/mob/living/simple_animal/sea/harvest_products(turf/site, skin)
	if (!sea_meat)
		return
	var/portions = harvest_skill_amount(sea_meat_amount, harvest_bonus)
	for (var/i = 1, i <= portions, i++)
		harvest_food(sea_meat, site)

// The land AI's reactions (attacked, scared) become a flight from whoever did it.
/mob/living/simple_animal/sea/do_behaviour(t_behaviour = null)
	if (stat != CONSCIOUS)
		return FALSE
	if (t_behaviour == "scared" || t_behaviour == "defends")
		sea_alarm(lastattacker)
	return FALSE

/mob/living/simple_animal/sea/handle_ai()
	if (stat != CONSCIOUS || client || !isturf(loc) || buckled || !canmove)
		return
	if (!sea_in_waters() && sea_head_home())
		return
	sea_ai()

/mob/living/simple_animal/sea/proc/sea_in_waters()
	var/zone = sea_zone_of(loc)
	return zone >= zone_min && zone <= zone_max

// Out of its waters: swims for the nearest water of its own zones in sight.
/mob/living/simple_animal/sea/proc/sea_head_home()
	if (!home_hint || sea_zone_of(home_hint) < zone_min || sea_zone_of(home_hint) > zone_max || get_dist(src, home_hint) > 12)
		home_hint = null
		var/best = 99
		for (var/turf/T in range(8, src))
			if (!sea_layer_cell(T) || T.iscovered())
				continue
			var/zone = sea_zone_of(T)
			if (zone < zone_min || zone > zone_max)
				continue
			var/d = get_dist(src, T)
			if (d < best)
				best = d
				home_hint = T
	return home_hint && sea_step_toward(home_hint)

// Hurt or frightened: what it does about it. Most kinds flee.
/mob/living/simple_animal/sea/proc/sea_alarm(atom/source)
	sea_start_flee(source)

/mob/living/simple_animal/sea/proc/sea_start_flee(atom/source)
	if (!source)
		return
	flee_from = get_turf(source)
	flee_until = world.time + SEA_FLEE_TIME

// One AI tick. Kinds override this; the base just flees or wanders.
/mob/living/simple_animal/sea/proc/sea_ai()
	if (sea_fleeing())
		return
	sea_idle_step()

// Takes a fleeing step while frightened. TRUE while fleeing.
/mob/living/simple_animal/sea/proc/sea_fleeing()
	if (!flee_from || world.time >= flee_until)
		flee_from = null
		return FALSE
	sea_step_away(flee_from)
	return TRUE

/mob/living/simple_animal/sea/proc/sea_idle_step()
	if (++idle_ticks < idle_every)
		return
	idle_ticks = 0
	sea_wander()

// ---- Movement ----

// Open sea it may swim into: never a boat, rock or another zone.
/mob/living/simple_animal/sea/proc/sea_can_enter(turf/T)
	if (!T || T.density || !sea_layer_cell(T) || T.iscovered())
		return FALSE
	var/zone = sea_zone_of(T)
	if (zone >= zone_min && zone <= zone_max)
		return TRUE
	// Out of its waters (spawned or pushed there): never farther out.
	var/here = sea_zone_of(loc)
	if (here >= zone_min && here <= zone_max)
		return FALSE
	var/target = here < zone_min ? zone_min : zone_max
	return abs(zone - target) <= abs(here - target)

/mob/living/simple_animal/sea/proc/sea_step(d)
	if (!d)
		return FALSE
	var/turf/T = get_step(src, d)
	if (!sea_can_enter(T))
		return FALSE
	set_dir(d)
	if (ai_step(T, swim_interval))
		swim_dir = d
		return TRUE
	return FALSE

// Steps in d, or the nearest direction either side of it.
/mob/living/simple_animal/sea/proc/sea_step_near(d)
	if (sea_step(d))
		return TRUE
	var/list/sides = shuffle(list(turn(d, 45), turn(d, -45)))
	for (var/s in sides)
		if (sea_step(s))
			return TRUE
	sides = shuffle(list(turn(d, 90), turn(d, -90)))
	for (var/s in sides)
		if (sea_step(s))
			return TRUE
	return FALSE

/mob/living/simple_animal/sea/proc/sea_step_toward(atom/A)
	var/turf/T = get_turf(A)
	if (!T || T == loc)
		return FALSE
	return sea_step_near(get_dir(src, T))

/mob/living/simple_animal/sea/proc/sea_step_away(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return FALSE
	var/d = T == loc ? pick(alldirs) : get_dir(T, src)
	return sea_step_near(d)

// Keeps on in its heading most of the time, turning now and then.
/mob/living/simple_animal/sea/proc/sea_wander()
	if (!swim_dir || prob(20))
		swim_dir = pick(alldirs)
	if (sea_step(swim_dir))
		return TRUE
	swim_dir = pick(alldirs)
	return sea_step_near(swim_dir)

// ---- Senses ----

// The nearest diver within range, or null.
/mob/living/simple_animal/sea/proc/sea_nearest_diver(range)
	var/best = range + 1
	. = null
	for (var/mob/living/M in range(range, src))
		if (!sea_diver(M))
			continue
		var/d = get_dist(src, M)
		if (d < best)
			best = d
			. = M

// Something frightening for a timid animal: a diver close by (farther when
// they carry a lamp), a boat's floodlight, or a fresh noise. Returns its turf.
/mob/living/simple_animal/sea/proc/sea_scare(diver_range = 2, lamp_range = 4)
	for (var/mob/living/M in range(lamp_range, src))
		if (!sea_diver(M))
			continue
		if (get_dist(src, M) <= diver_range || sea_lamp_lit(M))
			return get_turf(M)
	for (var/obj/structure/vehicleparts/shipwheel/W in range(lamp_range, src))
		if (W.light_range > 0)
			return get_turf(W)
	return sea_noise_heard(get_turf(src))

// Bites L: armour helps, and a diver's sealed suit is torn a little.
/mob/living/simple_animal/sea/proc/sea_bite(mob/living/L, damage, verb = "bites")
	if (!L || !Adjacent(L))
		return FALSE
	set_dir(get_dir(src, L))
	visible_message(SPAN_DANGER("\The [src] [verb] [L]!"))
	playsound(loc, attack_sound, 40, TRUE)
	if (ishuman(L))
		var/mob/living/human/H = L
		var/obj/item/organ/external/affecting = H.get_organ(ran_zone(pick("l_leg", "r_leg", "l_arm", "r_arm", "chest")))
		H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp = 1)
		sea_tear_suit(H, damage / 2)
	else
		L.adjustBruteLoss(damage)
	return TRUE

/proc/sea_tear_suit(mob/living/human/H, amount)
	var/obj/item/clothing/suit/pressure_suit/S = H.wear_suit
	if (!istype(S) || amount <= 0)
		return
	if (S.wear_down(amount))
		to_chat(H, SPAN_DANGER("Your suit tears open! Water floods in!"))
	else
		to_chat(H, SPAN_WARNING("Your suit is scored. Integrity [round(S.integrity)]%."))

// ---- Shoals ----

/mob/living/simple_animal/sea/shoal
	name = "silverfin shoal"
	desc = "A tight shoal of small silver fish that turn together in the water."
	icon = 'icons/mob/fish.dmi'
	icon_state = "fish2"
	icon_living = "fish2"
	icon_dead = "shoal_dead"
	dead_icon = 'icons/mob/sea_life.dmi'
	density = FALSE
	mob_size = MOB_TINY
	health = 8
	maxHealth = 8
	zone_min = SEA_ZONE_SHELF
	zone_max = SEA_ZONE_OPEN
	swim_interval = 6
	sea_meat_amount = 2

/mob/living/simple_animal/sea/shoal/darters
	name = "reef darters"
	desc = "A quick school of dark little fish that keep close to the rocks."
	icon_state = "fish1"
	icon_living = "fish1"
	zone_max = SEA_ZONE_SHELF
	swim_interval = 4

/mob/living/simple_animal/sea/shoal/sea_ai()
	var/turf/scare = sea_scare()
	if (scare)
		sea_start_flee(scare)
	if (sea_fleeing())
		return
	// Keep with the rest of the shoal: back towards the nearest one when apart.
	var/mob/living/simple_animal/sea/shoal/mate = null
	var/best = 7
	for (var/mob/living/simple_animal/sea/shoal/S in range(6, src))
		if (S == src || S.stat != CONSCIOUS || S.type != type)
			continue
		var/d = get_dist(src, S)
		if (d < best)
			best = d
			mate = S
	if (mate && best > 2)
		sea_step_toward(mate)
		return
	if (mate && prob(50))
		swim_dir = mate.swim_dir || swim_dir
	sea_wander()

// ---- Kelp turtle ----

/mob/living/simple_animal/sea/kelp_turtle
	name = "kelp turtle"
	desc = "A slow green sea turtle that grazes along the shelf. It only hurries when it is hurt."
	icon_state = "kelp_turtle"
	icon_living = "kelp_turtle"
	icon_dead = "kelp_turtle_dead"
	mob_size = MOB_MEDIUM
	health = 60
	maxHealth = 60
	zone_min = SEA_ZONE_SHELF
	zone_max = SEA_ZONE_SHELF
	swim_interval = 12
	idle_every = 3
	sea_meat = /obj/item/weapon/reagent_containers/food/snacks/meat
	sea_meat_amount = 4

/mob/living/simple_animal/sea/kelp_turtle/sea_ai()
	var/turf/noise = sea_noise_heard(get_turf(src))
	if (noise)
		sea_start_flee(noise)
	if (flee_from)
		// Hurrying away: a step every tick, at a swimmer's pace.
		swim_interval = 7
		if (sea_fleeing())
			return
	swim_interval = initial(swim_interval)
	sea_idle_step()

// ---- Reef eel ----

/mob/living/simple_animal/sea/reef_eel
	name = "reef eel"
	desc = "A long speckled eel that waits in a crevice and snaps at whatever swims too close."
	icon_state = "reef_eel_hidden"
	icon_living = "reef_eel"
	icon_dead = "reef_eel_dead"
	density = FALSE
	mob_size = MOB_SMALL
	health = 35
	maxHealth = 35
	zone_min = SEA_ZONE_SHELF
	zone_max = SEA_ZONE_OPEN
	swim_interval = 4
	melee_damage_lower = 6
	melee_damage_upper = 10
	sea_meat_amount = 2
	// Its crevice: the open water beside the rock it lives in.
	var/tmp/turf/den = null
	var/tmp/mob/living/prey = null
	var/tmp/rest_until = 0

#define EEL_LUNGE_RANGE 2
#define EEL_STRAY_LIMIT 4
#define EEL_REST_TIME (8 SECONDS)

/mob/living/simple_animal/sea/reef_eel/persistence_runtime_var(key)
	return (key in list("den", "prey", "rest_until")) || ..(key)

/mob/living/simple_animal/sea/reef_eel/death(gibbed, deathmessage)
	prey = null
	return ..(gibbed, deathmessage)

// A sea cell beside rock: somewhere for an eel to hide.
/proc/sea_crevice(turf/T)
	if (!sea_layer_cell(T) || T.iscovered())
		return FALSE
	for (var/d in cardinal)
		var/turf/N = get_step(T, d)
		if (N && !sea_layer_cell(N))
			return TRUE
	return FALSE

/mob/living/simple_animal/sea/reef_eel/proc/hide()
	if (icon_state != "reef_eel_hidden")
		icon_state = "reef_eel_hidden"

/mob/living/simple_animal/sea/reef_eel/proc/unhide()
	if (icon_state != icon_living)
		icon_state = icon_living

/mob/living/simple_animal/sea/reef_eel/sea_alarm(atom/source)
	// Cornered: bite back once, then bolt for the crevice.
	var/mob/living/L = source
	if (istype(L) && Adjacent(L) && health > maxHealth * 0.4)
		sea_bite(L, rand(melee_damage_lower, melee_damage_upper))
	prey = null
	rest_until = world.time + EEL_REST_TIME

/mob/living/simple_animal/sea/reef_eel/sea_ai()
	var/turf/here = get_turf(src)
	if (!den)
		den = sea_crevice(here) ? here : null
		if (!den)
			for (var/turf/T in orange(3, here))
				if (sea_crevice(T))
					den = T
					break
		if (!den)
			den = here
	if (prey && (QDELETED(prey) || !sea_diver(prey) || get_dist(prey, den) > EEL_STRAY_LIMIT))
		prey = null
	if (!prey && world.time >= rest_until)
		var/mob/living/M = null
		var/best = EEL_LUNGE_RANGE + 1
		for (var/mob/living/D in range(EEL_LUNGE_RANGE, den))
			if (sea_diver(D) && get_dist(den, D) < best)
				best = get_dist(den, D)
				M = D
		prey = M
	if (prey)
		unhide()
		if (Adjacent(prey))
			sea_bite(prey, rand(melee_damage_lower, melee_damage_upper))
			prey = null
			rest_until = world.time + EEL_REST_TIME
			return
		if (get_dist(src, den) < EEL_STRAY_LIMIT)
			sea_step_toward(prey)
		else
			prey = null
		return
	// Back to the crevice and out of sight.
	if (here != den)
		unhide()
		if (!sea_step_toward(den) && get_dist(src, den) > EEL_STRAY_LIMIT)
			den = null
		return
	hide()

#undef EEL_LUNGE_RANGE
#undef EEL_STRAY_LIMIT
#undef EEL_REST_TIME

// ---- Drift jelly ----

/mob/living/simple_animal/sea/drift_jelly
	name = "drift jelly"
	desc = "A pale jellyfish that glows softly as it drifts. Its trailing threads sting."
	icon_state = "drift_jelly"
	icon_living = "drift_jelly"
	icon_dead = "drift_jelly_dead"
	density = FALSE
	mob_size = MOB_TINY
	health = 12
	maxHealth = 12
	zone_min = SEA_ZONE_OPEN
	zone_max = SEA_ZONE_DEEP
	swim_interval = 20
	idle_every = 3
	sea_meat = null
	melee_damage_lower = 3
	melee_damage_upper = 5

/mob/living/simple_animal/sea/drift_jelly/New()
	..()
	set_light(2, 1, "#9fe4ff")

/mob/living/simple_animal/sea/drift_jelly/death(gibbed, deathmessage = "dims and folds up.")
	set_light(0)
	return ..(gibbed, deathmessage)

// Drifting cannot flee.
/mob/living/simple_animal/sea/drift_jelly/sea_alarm(atom/source)
	return

/mob/living/simple_animal/sea/drift_jelly/sea_ai()
	for (var/mob/living/M in range(1, src))
		if (sea_diver(M) && (M.loc == loc || prob(40)))
			sting(M)
	sea_idle_step()

/mob/living/simple_animal/sea/drift_jelly/Crossed(atom/movable/AM)
	..()
	if (stat == CONSCIOUS && isliving(AM) && sea_diver(AM))
		sting(AM)

// A hard dive suit is too thick for the threads.
/mob/living/simple_animal/sea/drift_jelly/proc/sting(mob/living/M)
	if (ishuman(M))
		var/mob/living/human/H = M
		if (istype(H.wear_suit, /obj/item/clothing/suit/pressure_suit/diving/hard))
			return FALSE
		H.apply_damage(rand(melee_damage_lower, melee_damage_upper), BURN, H.get_organ(ran_zone("chest")), H.run_armor_check(null, "bio"))
		to_chat(H, SPAN_DANGER("Threads of \the [src] sting you!"))
		return TRUE
	M.adjustBurnLoss(rand(melee_damage_lower, melee_damage_upper))
	return TRUE

// ---- Spawning ----

/datum/sea_species
	var/name
	var/path
	var/zone_min
	var/zone_max
	var/density // animals per 1000 cells of its zones
	var/max_target
	var/herd_min = 1
	var/herd_max = 1
	var/needs_crevice = FALSE

/datum/sea_species/New(_name, _path, _zmin, _zmax, _density, _max, _hmin = 1, _hmax = 1, _crevice = FALSE)
	..()
	name = _name
	path = _path
	zone_min = _zmin
	zone_max = _zmax
	density = _density
	max_target = _max
	herd_min = _hmin
	herd_max = _hmax
	needs_crevice = _crevice

/proc/sea_life_species()
	return list(
		new /datum/sea_species("silverfin shoal", /mob/living/simple_animal/sea/shoal, SEA_ZONE_SHELF, SEA_ZONE_OPEN, 0.8, 30, 2, 3),
		new /datum/sea_species("reef darters", /mob/living/simple_animal/sea/shoal/darters, SEA_ZONE_SHELF, SEA_ZONE_SHELF, 0.8, 15, 2, 3),
		new /datum/sea_species("kelp turtle", /mob/living/simple_animal/sea/kelp_turtle, SEA_ZONE_SHELF, SEA_ZONE_SHELF, 0.5, 10, 1, 2),
		new /datum/sea_species("reef eel", /mob/living/simple_animal/sea/reef_eel, SEA_ZONE_SHELF, SEA_ZONE_OPEN, 0.3, 12, 1, 1, TRUE),
		new /datum/sea_species("drift jelly", /mob/living/simple_animal/sea/drift_jelly, SEA_ZONE_OPEN, SEA_ZONE_DEEP, 0.8, 25, 1, 3),
	)

var/global/list/sea_life_table = null
var/global/sea_life_last_report = "not started"

// Target count of a species from the size of its zones on this map.
/proc/sea_species_target(datum/sea_species/S)
	var/cells = 0
	for (var/z = S.zone_min, z <= S.zone_max, z++)
		cells += seabed_zone_counts[z]
	return min(S.max_target, round(cells * S.density / 1000))

/proc/sea_spawn_site_ok(turf/T, datum/sea_species/S)
	if (!sea_layer_cell(T) || T.iscovered() || T.density)
		return FALSE
	var/zone = sea_zone_of(T)
	if (zone < S.zone_min || zone > S.zone_max)
		return FALSE
	if (S.needs_crevice && !sea_crevice(T))
		return FALSE
	for (var/mob/living/L in T)
		return FALSE
	return TRUE

/proc/sea_find_site(datum/sea_species/S, z)
	for (var/i = 1, i <= SEA_SPAWN_ATTEMPTS, i++)
		var/turf/T = locate(rand(1, world.maxx), rand(1, world.maxy), z)
		if (!sea_spawn_site_ok(T, S))
			continue
		if (ecology_visible_to_players(T, SEA_SPAWN_VIEW_MARGIN))
			continue
		return T
	return null

// Tops up sea life below target, out of sight. Run by the ecology spawner
// each cycle; returns the animals placed.
/proc/sea_life_cycle()
	var/z = sea_layer_z()
	if (!z || !seabed_zones_ready || !map)
		sea_life_last_report = "no seabed on this map yet"
		return 0
	if (!sea_life_table)
		sea_life_table = sea_life_species()
	var/list/counts = list()
	var/total = 0
	for (var/mob/living/simple_animal/sea/A in living_mob_list)
		if (A.stat == DEAD || A.client)
			continue
		counts["[A.type]"] += 1
		total++
	var/cap = map.sea_life_cap
	var/budget = SEA_SPAWN_BUDGET
	var/placed = 0
	var/list/notes = list()
	for (var/datum/sea_species/S in shuffle(sea_life_table.Copy()))
		var/have = counts["[S.path]"]
		var/target = sea_species_target(S)
		var/deficit = min(target - have, cap - total, budget)
		if (deficit > 0)
			var/turf/site = sea_find_site(S, z)
			if (site)
				var/herd = min(deficit, rand(S.herd_min, S.herd_max))
				var/n = 0
				for (var/i = 1, i <= herd, i++)
					var/turf/T = site
					if (i > 1)
						T = locate(site.x + rand(-SEA_HERD_RANGE, SEA_HERD_RANGE), site.y + rand(-SEA_HERD_RANGE, SEA_HERD_RANGE), z)
						if (!sea_spawn_site_ok(T, S))
							continue
					new S.path(T)
					n++
				have += n
				total += n
				placed += n
				budget -= n
		notes += "[S.name] [have]/[target]"
	sea_life_last_report = "[total]/[cap] sea animals, +[placed]: [jointext(notes, ", ")]"
	return placed

#undef SEA_FLEE_TIME
#undef SEA_NOISE_LIFE
#undef SEA_NOISES_MAX
#undef SEA_SPAWN_BUDGET
#undef SEA_SPAWN_ATTEMPTS
#undef SEA_SPAWN_VIEW_MARGIN
#undef SEA_HERD_RANGE
