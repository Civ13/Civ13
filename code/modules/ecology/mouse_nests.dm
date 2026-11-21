// Mouse nests: where mice come from.
//
// Mice no longer appear out of rotten food. They live in nests: wild burrows
// that the ecology spawner places in suitable outdoor habitat, and house nests
// beside food people leave within reach. A nest is one saved structure that
// holds a population number. Only a few of those mice are ever real mobs: at
// dusk and night (or any time indoors) one or two dart out of a nest near a
// player, wander a few tiles and run back inside when someone comes close.
//
// All the slow ecology (growth, starving) happens in settle(), which the
// mouse_nests process runs for at most two nests every 10 seconds
// and which applies every whole interval that passed since the last settle.
// Nothing scans the world: nests keep their own registry, the wild top-up
// reuses the ecology spawner's habitat index, and emitted mice are not saved
// because the nest's number is the truth.

#define MOUSE_NEST_CAP 60 // wild burrows and house nests together
#define MOUSE_BURROW_CAP 30
#define MOUSE_BURROW_TILES 4000 // habitat tiles per wild burrow
#define MOUSE_BURROWS_PER_CYCLE 2
#define MOUSE_BURROW_FLOOR 2
#define MOUSE_BURROW_MAX 4
#define MOUSE_HOUSE_MAX 8
#define MOUSE_SETTLE_MINUTES 5
#define MOUSE_SETTLE_MAX_STEPS 12
#define MOUSE_OUT_PER_NEST 2
#define MOUSE_OUT_CAP 40
#define MOUSE_EMERGE_CHANCE 25
#define MOUSE_THREAT_RANGE 4
#define MOUSE_WANDER_RANGE 5
#define MOUSE_TIME_OUT (3 MINUTES)
#define MOUSE_STRAY_LIFE (10 MINUTES)
#define MOUSE_DIG_TIME 100
#define MOUSE_FORAGE_RANGE 5
#define MOUSE_SPREAD_RANGE 12
#define MOUSE_SPREAD_CHANCE 20
#define MOUSE_NEST_CROWD 3
#define MOUSE_NEST_CROWD_RANGE 15
#define RODENT_PROOF 0
#define RODENT_GNAW 1
#define RODENT_OPEN 2

var/global/list/mouse_nest_list = list()
var/global/list/mouse_out_list = list()
var/global/mouse_nest_cursor = 1
var/global/datum/ecology_species/mouse_burrow_habitat = null

// Dusk and night outdoors; indoors mice keep their own hours.
/proc/mouse_active_time(turf/T)
	var/area/A = get_area(T)
	if (A && A.location != AREA_OUTSIDE)
		return TRUE
	return time_of_day == "Evening" || time_of_day == "Night" || time_of_day == "Dark Night"

/obj/structure/mouse_nest
	name = "mouse nest"
	desc = "A hole at the edge of the floor, packed with shredded straw."
	icon = 'icons/obj/mouse_nests.dmi'
	icon_state = "nest_light"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = TURF_LAYER + 0.2
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/population = 3
	var/last_settle = null // realtime minutes, as text so the save keeps every digit
	var/commensal = TRUE // FALSE for wild burrows
	var/fleas = FALSE
	var/tmp/list/out_mice = null
	var/tmp/list/scan_traps = null // mouse traps seen by the last forage_scan()
	var/tmp/list/scan_baits = null // poison bait seen by the last forage_scan()
	var/overrun_steps = 0 // steps in a row at full size, for fleas

/obj/structure/mouse_nest/burrow
	name = "mouse burrow"
	desc = "A small hole in the ground with a ring of kicked-out earth."
	icon_state = "burrow"
	population = 3
	commensal = FALSE
	flammable = FALSE

// Out mice are live mobs of this process; the population number is what saves.
/obj/structure/mouse_nest/persistence_runtime_var(key)
	return key == "out_mice" || key == "scan_traps" || key == "scan_baits" || ..()

/obj/structure/mouse_nest/New()
	..()
	out_mice = list()
	mouse_nest_list |= src
	if (isnull(last_settle))
		last_settle = trap_minutes_text(trap_now_minutes())
	population = clamp(population, 0, max_population())
	update_icon()

/obj/structure/mouse_nest/after_load()
	..()
	mouse_nest_list |= src
	if (!out_mice)
		out_mice = list()
	// Downtime is not mouse time: the clock restarts at load.
	last_settle = trap_minutes_text(trap_now_minutes())
	update_icon()

/obj/structure/mouse_nest/Destroy()
	mouse_nest_list -= src
	for (var/mob/living/simple_animal/mouse/M in out_mice)
		M.lose_home()
	out_mice = null
	return ..()

/obj/structure/mouse_nest/proc/max_population()
	return commensal ? MOUSE_HOUSE_MAX : MOUSE_BURROW_MAX

/obj/structure/mouse_nest/update_icon()
	if (!commensal)
		icon_state = "burrow"
	else if (population <= 3)
		icon_state = "nest_light"
	else if (population <= 6)
		icon_state = "nest_used"
	else
		icon_state = "nest_overrun"

/obj/structure/mouse_nest/proc/size_text()
	if (!commensal)
		return population >= MOUSE_BURROW_MAX ? "Fresh earth and tracks around it; it is busy." : "A few tracks lead in and out."
	if (population <= 3)
		return "There are a few droppings around it."
	if (population <= 6)
		return "It is well-used: droppings, gnawed husks and a worn path."
	return "It is overrun: the straw is heaving and droppings are everywhere."

/obj/structure/mouse_nest/examine(mob/user, distance = -1)
	..(user, distance)
	to_chat(user, SPAN_NOTICE(size_text()))
	if (fleas)
		to_chat(user, SPAN_WARNING("Fleas hop in the straw. Don't sleep near it, and wear gloves to dig it out."))
	to_chat(user, SPAN_NOTICE("A shovel or digging stick would dig it out."))

// What mice can reach (see docs/mouse-nests.md): loose food and seed, ripe
// crops, baskets and racks are open; wooden chests, crates and pits are gnawed
// into at a quarter of the rate; fired clay, metal, stone and cold stores keep
// them out, and so does anything a person carries.
/atom/movable/proc/rodent_access_level()
	return RODENT_PROOF

/obj/structure/storage_container
	var/rodent_access = RODENT_GNAW

/obj/structure/storage_container/rodent_access_level()
	return rodent_access

/obj/structure/storage_container/basket
	rodent_access = RODENT_OPEN

/obj/structure/storage_container/rack
	rodent_access = RODENT_OPEN

/obj/structure/storage_container/storage_jar
	rodent_access = RODENT_PROOF

/obj/structure/closet/rodent_access_level()
	if (istype(src, /obj/structure/closet/fridge) || istype(src, /obj/structure/closet/ice_house) || istype(src, /obj/structure/closet/crate/freezer))
		return RODENT_PROOF
	if (istype(src, /obj/structure/closet/crate/steel) || istype(src, /obj/structure/closet/crate/iron) || istype(src, /obj/structure/closet/crate/stone) || istype(src, /obj/structure/closet/crate/glass) || istype(src, /obj/structure/closet/crate/brick))
		return RODENT_PROOF
	return RODENT_GNAW

/proc/rodent_access_text(level)
	switch (level)
		if (RODENT_OPEN)
			return "Mice can get into it easily."
		if (RODENT_GNAW)
			return "Mice could gnaw their way in, slowly."
	return "Mice cannot get into it."

/proc/rodent_food_item(obj/item/I)
	if (istype(I, /obj/item/stack/farming/seeds))
		return TRUE
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/mouse_poison_bait))
		return FALSE
	return istype(I, /obj/item/weapon/reagent_containers/food/snacks) && !istype(I, /obj/item/weapon/reagent_containers/food/snacks/poo)

// One look around the nest. Each entry is list(thing, access, holder):
// holder is the store it sits in, or its turf.
/obj/structure/mouse_nest/proc/forage_scan()
	var/list/found = list()
	scan_traps = list()
	scan_baits = list()
	for (var/turf/T in range(MOUSE_FORAGE_RANGE, src))
		for (var/atom/movable/A in T)
			if (istype(A, /obj/item/weapon/mousetrap) || istype(A, /obj/structure/stone_age_trap/deadfall))
				scan_traps += A
				continue
			if (istype(A, /obj/item/weapon/reagent_containers/food/snacks/mouse_poison_bait))
				scan_baits += A
				continue
			if (rodent_food_item(A))
				found[++found.len] = list(A, RODENT_OPEN, T)
			else if (istype(A, /obj/structure/farming/plant))
				var/obj/structure/farming/plant/P = A
				if (!P.vstatic && P.readyHarvest())
					found[++found.len] = list(P, RODENT_OPEN, T)
			else if (istype(A, /obj/structure/storage_container) || istype(A, /obj/structure/closet))
				if (istype(A, /obj/structure/closet))
					var/obj/structure/closet/C = A
					if (C.opened)
						continue
				var/level = A.rodent_access_level()
				if (level == RODENT_PROOF)
					continue
				var/list/inside = A.contents
				if (istype(A, /obj/structure/storage_container))
					var/obj/structure/storage_container/SC = A
					inside = SC.stored_items()
				for (var/obj/item/I in inside)
					if (rodent_food_item(I))
						found[++found.len] = list(I, level, A)
	return found

/proc/rodent_food_units(list/scan)
	. = 0
	for (var/list/entry in scan)
		if (QDELETED(entry[1]))
			continue
		. += entry[2] == RODENT_OPEN ? 1 : 0.25
	. = round(.)

// Food mice can reach from this nest, in units: one per open item, a quarter per gnawable one.
/obj/structure/mouse_nest/proc/reachable_food_units()
	return rodent_food_units(forage_scan())

// Applies every whole interval since the last settle, at most MOUSE_SETTLE_MAX_STEPS.
// Returns the number of intervals applied. One look around serves every step.
/obj/structure/mouse_nest/proc/settle(now = trap_now_minutes())
	var/last = trap_minutes(last_settle)
	var/steps = round((now - last) / MOUSE_SETTLE_MINUTES)
	if (steps <= 0)
		return 0
	if (steps > MOUSE_SETTLE_MAX_STEPS)
		last = now - MOUSE_SETTLE_MAX_STEPS * MOUSE_SETTLE_MINUTES
		steps = MOUSE_SETTLE_MAX_STEPS
	last_settle = trap_minutes_text(last + steps * MOUSE_SETTLE_MINUTES)
	var/list/scan = forage_scan()
	for (var/i = 1, i <= steps, i++)
		settle_step(scan)
		if (QDELETED(src))
			return i
	flea_bites()
	update_icon()
	return steps

/obj/structure/mouse_nest/proc/settle_step(list/scan = null)
	if (isnull(scan))
		scan = forage_scan()
	var/food = rodent_food_units(scan)
	if (food > 0 && population > 0)
		feed(scan)
	if (!commensal)
		// A burrow holds steady on wild seed; winter stops it breeding.
		if (population < MOUSE_BURROW_FLOOR && !trap_cold_season(src))
			population++
		else if (food > population && population < MOUSE_BURROW_MAX && !trap_cold_season(src))
			population++
	else if (food > population && population < MOUSE_HOUSE_MAX)
		population++
	else if (food <= 0)
		population--
	// Cats (and dogs, at half) hunt the nest down and stop it spreading.
	var/hunted = predator_pressure()
	if (hunted > 0)
		population -= round(hunted) + (prob((hunted - round(hunted)) * 100) ? 1 : 0)
	// Set traps nearby take a mouse each (mouse_traps.dm).
	if (scan_traps && scan_traps.len)
		spring_traps(scan_traps)
	// Poison bait nearby (mouse_poison_fleas.dm).
	if (scan_baits && scan_baits.len)
		take_bait(scan_baits)
	flea_step()
	if (population <= 0)
		qdel(src)
		return
	if (!hunted && food > 0 && population >= max_population() && prob(MOUSE_SPREAD_CHANCE))
		try_spread(scan)

// Mice eat half their number in food each step, from open stores first.
/obj/structure/mouse_nest/proc/feed(list/scan)
	var/bites = round((population + 1) / 2)
	var/list/open = list()
	var/list/gnaw = list()
	for (var/list/entry in scan)
		if (entry[2] == RODENT_OPEN)
			open[++open.len] = entry
		else
			gnaw[++gnaw.len] = entry
	. = 0
	while (bites-- > 0)
		var/list/entry = null
		while (open.len && !entry)
			entry = pick(open)
			if (QDELETED(entry[1]))
				open -= list(entry)
				entry = null
		if (!entry && gnaw.len && prob(25))
			entry = pick(gnaw)
			if (QDELETED(entry[1]))
				gnaw -= list(entry)
				entry = null
		if (!entry)
			continue
		var/atom/movable/eaten = entry[1]
		rodent_eat(eaten)
		.++
		if (QDELETED(eaten))
			open -= list(entry)
			gnaw -= list(entry)
		rodent_foul_neighbour(entry[3], eaten, scan)

/proc/rodent_eat(atom/movable/A)
	if (istype(A, /obj/item/stack/farming/seeds))
		var/obj/item/stack/farming/seeds/S = A
		if (S.amount >= 2)
			S.amount -= 1
			S.update_icon()
		else
			qdel(S)
	else if (istype(A, /obj/structure/farming/plant))
		var/obj/structure/farming/plant/P = A
		P.rodent_strip_harvest()
	else
		qdel(A)

// Droppings and nibbling spoil one more thing in the same store.
/proc/rodent_foul_neighbour(holder, atom/movable/eaten, list/scan)
	for (var/list/entry in scan)
		if (entry[3] != holder || entry[1] == eaten || QDELETED(entry[1]))
			continue
		var/obj/item/weapon/reagent_containers/food/F = entry[1]
		if (istype(F) && !F.rodent_fouled)
			F.rodent_foul()
			return F
	return null

/obj/item/weapon/reagent_containers/food
	var/rodent_fouled = FALSE

/obj/item/weapon/reagent_containers/food/proc/rodent_foul()
	if (rodent_fouled)
		return FALSE
	rodent_fouled = TRUE
	name = "gnawed [name]"
	overlays += image('icons/obj/mouse_nests.dmi', "gnawed")
	if (reagents)
		reagents.add_reagent("food_poisoning", 1)
		note_food_toxin("fouled by mice")
	return TRUE

// The ripe crop is eaten; the plant lives and grows another harvest.
/obj/structure/farming/plant/proc/rodent_strip_harvest()
	if (vstatic || !readyHarvest())
		return FALSE
	stage = max(1, readyStageMin - 1)
	var/sprite_name = sprite_plant ? sprite_plant : plant
	icon_state = "[sprite_name]-grow[stage]"
	desc = "A young [plant] plant. Something has eaten its crop."
	name = "young [plant] plant"
	return TRUE

// House nests found on soft ground and wooden floors, never stone, tile or metal.
/proc/mouse_nest_floor_ok(turf/T)
	if (!T || T.density)
		return FALSE
	if (istype(T, /turf/floor/dirt))
		return !istype(T, /turf/floor/dirt/flooded)
	return istype(T, /turf/floor/grass) || istype(T, /turf/floor/wood) || istype(T, /turf/floor/wood_broken) || istype(T, /turf/floor/carpet)

/proc/mouse_nest_site_error(turf/T)
	if (!mouse_nest_floor_ok(T))
		return "floor"
	if (turf_is_above_ground(T)) // mice keep to the ground floor and cellars
		return "upstairs"
	if (locate(/obj/structure/mouse_nest) in T)
		return "nest"
	for (var/atom/movable/A in T)
		if (A.density)
			return "blocked"
	var/near = 0
	for (var/obj/structure/mouse_nest/N in mouse_nest_list)
		if (N.z == T.z && get_dist(N, T) <= MOUSE_NEST_CROWD_RANGE)
			near++
			if (near >= MOUSE_NEST_CROWD)
				return "crowded"
	if (ecology_visible_to_players(T, 7))
		return "seen"
	return null

// A full nest with food sends a colony to found a house nest beside a store.
/obj/structure/mouse_nest/proc/try_spread(list/scan)
	if (mouse_nest_list.len >= MOUSE_NEST_CAP || !scan.len)
		return null
	var/list/entry = pick(scan)
	var/turf/store = get_turf(entry[3])
	if (!store)
		return null
	for (var/i = 1, i <= 8, i++)
		var/turf/T = locate(store.x + rand(-2, 2), store.y + rand(-2, 2), store.z)
		if (!T || get_dist(T, src) > MOUSE_SPREAD_RANGE)
			continue
		if (mouse_nest_site_error(T))
			continue
		var/obj/structure/mouse_nest/N = new /obj/structure/mouse_nest(T)
		N.population = 2
		N.update_icon()
		population = max(1, population - 2)
		return N
	return null

// Lets one mouse out when someone is near enough to meet it.
/obj/structure/mouse_nest/proc/try_emerge()
	if (!isturf(loc) || population <= 0)
		return null
	if (out_mice.len >= min(MOUSE_OUT_PER_NEST, population) || mouse_out_list.len >= MOUSE_OUT_CAP)
		return null
	if (!mouse_active_time(loc) || !ecology_observer_near(loc))
		return null
	if (!prob(MOUSE_EMERGE_CHANCE))
		return null
	var/mob/living/simple_animal/mouse/M = new /mob/living/simple_animal/mouse(loc)
	M.set_home(src)
	return M

// A mouse came back inside: it was always part of the population.
/obj/structure/mouse_nest/proc/mouse_returned(mob/living/simple_animal/mouse/M)
	out_mice -= M
	M.home = null
	qdel(M)

// A mouse from this nest was killed.
/obj/structure/mouse_nest/proc/mouse_died(mob/living/simple_animal/mouse/M)
	out_mice -= M
	population = max(0, population - 1)
	update_icon()

/obj/structure/mouse_nest/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/plough/digging_stick) || is_tool(W, TOOL_SHOVEL))
		dig_out(user)
		return TRUE
	return ..()

/obj/structure/mouse_nest/proc/dig_out(mob/user)
	user.visible_message(SPAN_NOTICE("[user] starts digging out \the [src]."), SPAN_NOTICE("You start digging out \the [src]."))
	if (!do_after(user, MOUSE_DIG_TIME, src))
		return FALSE
	if (QDELETED(src))
		return FALSE
	var/turf/T = get_turf(src)
	if (fleas && ishuman(user))
		var/mob/living/human/H = user
		if (!H.gloves)
			mouse_flea_dig(H)
	var/fleeing = min(population - out_mice.len, rand(1, 3))
	user.visible_message(SPAN_NOTICE("[user] digs out \the [src][fleeing > 0 ? " and mice scatter from it" : ""]!"))
	qdel(src)
	for (var/i = 1, i <= fleeing, i++)
		var/mob/living/simple_animal/mouse/M = new /mob/living/simple_animal/mouse(T)
		M.become_stray()
		M.do_behaviour("scared")
	return TRUE

// ---------------------------------------------------------------- wild burrows

/proc/mouse_burrow_count()
	. = 0
	for (var/obj/structure/mouse_nest/N in mouse_nest_list)
		if (!N.commensal)
			.++

// Burrow habitat: grass and dirt in temperate, semiarid, savanna, taiga and jungle land.
/datum/ecology_spawner/proc/mouse_burrow_species()
	if (!mouse_burrow_habitat)
		mouse_burrow_habitat = eco_species("mouse burrow", list(/obj/structure/mouse_nest/burrow), list("temperate", "semiarid", "savanna", "taiga", "jungle"), ECO_GRASS | ECO_DIRT, 0, MOUSE_BURROW_CAP, 1, 1)
	var/datum/ecology_species/S = mouse_burrow_habitat
	var/tiles = index_habitat(S)
	S.target = tiles <= 0 ? 0 : clamp(round(tiles / MOUSE_BURROW_TILES), 1, MOUSE_BURROW_CAP)
	return S

// Called from cycle(): places a few burrows out of sight until the wild target is met.
/datum/ecology_spawner/proc/mouse_burrow_cycle()
	var/datum/ecology_species/S = mouse_burrow_species()
	var/wild = mouse_burrow_count()
	var/placed = 0
	while (placed < MOUSE_BURROWS_PER_CYCLE && wild < S.target && mouse_nest_list.len < MOUSE_NEST_CAP)
		var/turf/T = find_site(S)
		if (!T)
			break
		new /obj/structure/mouse_nest/burrow(T)
		wild++
		placed++
	return "Mouse burrows [wild]/[S.target], nests [mouse_nest_list.len]/[MOUSE_NEST_CAP]"

// ---------------------------------------------------------------- the mouse side

/mob/living/simple_animal/mouse
	var/tmp/obj/structure/mouse_nest/home = null
	var/tmp/left_home_at = 0
	var/tmp/stray = FALSE
	var/tmp/stray_since = 0

/mob/living/simple_animal/mouse/persistence_runtime_var(key)
	return key == "home" || key == "left_home_at" || key == "stray_since" || key == "stray" || ..()

/mob/living/simple_animal/mouse/proc/set_home(obj/structure/mouse_nest/N)
	home = N
	left_home_at = world.time
	should_save = FALSE // the nest's population already counts this mouse
	N.out_mice |= src
	mouse_out_list |= src

/mob/living/simple_animal/mouse/proc/lose_home()
	home = null
	become_stray()

// A mouse with no nest lives a while, then slips away out of sight.
/mob/living/simple_animal/mouse/proc/become_stray()
	should_save = FALSE
	stray = TRUE
	stray_since = world.time
	mouse_out_list |= src

/mob/living/simple_animal/mouse/proc/threat_near()
	for (var/mob/living/L in range(MOUSE_THREAT_RANGE, src))
		if (L.stat == DEAD || L == src)
			continue
		if (ishuman(L) || istype(L, /mob/living/simple_animal/pet/cat) || istype(L, /mob/living/simple_animal/pet/dog))
			return L
	return null

/mob/living/simple_animal/mouse/proc/go_home()
	if (!home || QDELETED(home))
		home = null
		return FALSE
	if (get_turf(src) == get_turf(home) || get_dist(src, home) <= 1)
		home.mouse_returned(src)
		return TRUE
	walk_to(src, home, 0, 2)
	return TRUE

/mob/living/simple_animal/mouse/do_behaviour(var/t_behaviour = null)
	if (client || stat != CONSCIOUS)
		return ..()
	if (home)
		if (QDELETED(home))
			lose_home()
		else if (threat_near() || world.time - left_home_at > MOUSE_TIME_OUT || !mouse_active_time(home.loc))
			go_home()
			return "scared"
		else if (get_dist(src, home) > MOUSE_WANDER_RANGE)
			step_towards(src, home)
			return "wander"
	else if (stray && world.time - stray_since > MOUSE_STRAY_LIFE)
		var/turf/T = get_turf(src)
		if (!T || !ecology_visible_to_players(T, 7))
			qdel(src)
			return null
	return ..()

/mob/living/simple_animal/mouse/death()
	if (home && !QDELETED(home))
		home.mouse_died(src)
	home = null
	mouse_out_list -= src
	return ..()

/mob/living/simple_animal/mouse/Destroy()
	if (home && !QDELETED(home))
		home.out_mice -= src
	home = null
	mouse_out_list -= src
	return ..()
