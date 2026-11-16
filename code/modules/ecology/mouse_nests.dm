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

/obj/structure/mouse_nest/burrow
	name = "mouse burrow"
	desc = "A small hole in the ground with a ring of kicked-out earth."
	icon_state = "burrow"
	population = 3
	commensal = FALSE
	flammable = FALSE

// Out mice are live mobs of this process; the population number is what saves.
/obj/structure/mouse_nest/persistence_runtime_var(key)
	return key == "out_mice" || ..()

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
	to_chat(user, SPAN_NOTICE("A shovel or digging stick would dig it out."))

// Food mice can reach from this nest, in units. Store access lands with the
// house nests; until then nests live on what wild ground provides.
/obj/structure/mouse_nest/proc/reachable_food_units()
	return 0

// Applies every whole interval since the last settle, at most MOUSE_SETTLE_MAX_STEPS.
// Returns the number of intervals applied.
/obj/structure/mouse_nest/proc/settle(now = trap_now_minutes())
	var/last = trap_minutes(last_settle)
	var/steps = round((now - last) / MOUSE_SETTLE_MINUTES)
	if (steps <= 0)
		return 0
	if (steps > MOUSE_SETTLE_MAX_STEPS)
		last = now - MOUSE_SETTLE_MAX_STEPS * MOUSE_SETTLE_MINUTES
		steps = MOUSE_SETTLE_MAX_STEPS
	last_settle = trap_minutes_text(last + steps * MOUSE_SETTLE_MINUTES)
	for (var/i = 1, i <= steps, i++)
		settle_step()
		if (QDELETED(src))
			return i
	update_icon()
	return steps

/obj/structure/mouse_nest/proc/settle_step()
	var/food = reachable_food_units()
	if (!commensal)
		// A burrow holds steady on wild seed; winter stops it breeding.
		if (population < MOUSE_BURROW_FLOOR && !trap_cold_season(src))
			population++
		else if (food > population && population < MOUSE_BURROW_MAX && !trap_cold_season(src))
			population++
		return
	if (food > population && population < MOUSE_HOUSE_MAX)
		population++
	else if (food <= 0)
		population--
	if (population <= 0)
		qdel(src)

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
