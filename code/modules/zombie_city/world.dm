// The zombie city as a raid world (docs/zombie-city.md). A map whose metadata
// declares zombie_city = TRUE is generated at round start from a new seed by
// the city generator (zombie_city_generate, looked up by name so either side
// can merge first). Raiders arrive at the city's insertion points and leave
// from its evacuation points; two of those are open at a time, in turns, and
// leaving takes a 30-second wait at an open one. In a resetting raid world
// (region_raid_reset.dm) the city collapses and is generated again each cycle.

#define ZOMBIE_CITY_EVAC_OPEN 2
#define ZOMBIE_CITY_EVAC_TURN (20 MINUTES)
#define ZOMBIE_CITY_EVAC_WAIT (30 SECONDS)

var/global/list/zombie_city_insertions = list()
var/global/list/zombie_city_evacuations = list() // ordered by ordinal
var/global/zombie_city_seed = null
var/global/zombie_city_evac_turn = 0

/proc/zombie_city_map()
	return map && ("zombie_city" in map.vars) && map.vars["zombie_city"]

/proc/zombie_city_add_insertion(turf/T)
	if(!isturf(T)) return FALSE
	zombie_city_insertions |= T
	return TRUE

/proc/zombie_city_add_evacuation(turf/T, ordinal = 0)
	if(!isturf(T)) return null
	var/obj/structure/region_gate/raid_exit/zombie_city/E = new(T)
	E.set_ordinal(ordinal)
	zombie_city_evacuations += E
	zombie_city_sort_evacuations()
	return E

/proc/zombie_city_sort_evacuations()
	var/list/sorted = list()
	for(var/obj/structure/region_gate/raid_exit/zombie_city/E in zombie_city_evacuations)
		if(QDELETED(E)) continue
		var/at = sorted.len + 1
		for(var/i in 1 to sorted.len)
			var/obj/structure/region_gate/raid_exit/zombie_city/other = sorted[i]
			if(E.ordinal < other.ordinal)
				at = i
				break
		sorted.Insert(at, E)
	zombie_city_evacuations = sorted

// An insertion point no raider has used in the last minute, else any.
/proc/zombie_city_arrival_turf()
	if(!zombie_city_insertions.len) return null
	var/list/free = list()
	for(var/turf/T in zombie_city_insertions)
		var/busy = FALSE
		for(var/mob/living/human/H in range(3, T))
			busy = TRUE
			break
		if(!busy) free += T
	return pick(free.len ? free : zombie_city_insertions)

// Which evacuation points are open this turn: ZOMBIE_CITY_EVAC_OPEN of them,
// moving round the list each turn.
/proc/zombie_city_evac_open(obj/structure/region_gate/raid_exit/zombie_city/E)
	var/count = zombie_city_evacuations.len
	if(!count) return FALSE
	if(count <= ZOMBIE_CITY_EVAC_OPEN) return TRUE
	var/index = zombie_city_evacuations.Find(E)
	if(!index) return FALSE
	var/first = (zombie_city_evac_turn * ZOMBIE_CITY_EVAC_OPEN) % count
	for(var/i in 0 to ZOMBIE_CITY_EVAC_OPEN - 1)
		if(((first + i) % count) + 1 == index) return TRUE
	return FALSE

/proc/zombie_city_open_names()
	var/list/names = list()
	for(var/obj/structure/region_gate/raid_exit/zombie_city/E in zombie_city_evacuations)
		if(zombie_city_evac_open(E)) names += E.name
	return english_list(names)

/proc/zombie_city_next_turn()
	if(!zombie_city_evacuations.len) return
	zombie_city_evac_turn++
	to_chat(world, SPAN_NOTICE("Evacuation points now open: [zombie_city_open_names()]."))

/proc/zombie_city_start()
	if(!zombie_city_map() || zombie_city_seed) return FALSE
	zombie_city_seed = rand(1, 16777215) // exact in a BYOND number, so the logged seed rebuilds the city
	log_game("Zombie city: generating with seed [num2text(zombie_city_seed, 9)].")
	world.log << "Zombie city: seed [num2text(zombie_city_seed, 9)]"
	var/generate = text2path("/proc/zombie_city_generate")
	if(!generate)
		log_game("Zombie city: no generator in this build; the map stays as it is.")
		return FALSE
	var/datum/layout = call(generate)(zombie_city_seed, 1, world.maxz >= 2 ? 2 : 0)
	if(!layout)
		message_admins("Zombie city: the generator failed for seed [num2text(zombie_city_seed, 9)].")
		return FALSE
	// Until the generator calls the add procs itself, read its layout.
	if(!zombie_city_insertions.len && ("entries" in layout.vars))
		for(var/turf/T in layout.vars["entries"])
			zombie_city_add_insertion(T)
	if(!zombie_city_evacuations.len && ("exits" in layout.vars))
		var/ordinal = 0
		for(var/turf/T in layout.vars["exits"])
			zombie_city_add_evacuation(T, ++ordinal)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(zombie_city_next_turn)), ZOMBIE_CITY_EVAC_TURN, TIMER_LOOP)
	return TRUE

/hook/roundstart/proc/zombie_city_roundstart()
	zombie_city_start()
	return TRUE

/obj/structure/region_gate/raid_exit/zombie_city
	name = "evacuation point"
	desc = "A marked pickup point at the edge of the city. Only some are open at a time; wait here to be taken home with what you carry."
	var/ordinal = 0
	var/list/waiting = list()

/obj/structure/region_gate/raid_exit/zombie_city/Destroy()
	zombie_city_evacuations -= src
	waiting = null
	return ..()

/obj/structure/region_gate/raid_exit/zombie_city/proc/set_ordinal(value)
	ordinal = value
	name = ordinal ? "evacuation point [ordinal]" : "evacuation point"

/obj/structure/region_gate/raid_exit/zombie_city/examine(mob/user)
	..()
	to_chat(user, zombie_city_evac_open(src) ? SPAN_NOTICE("It is open now.") : SPAN_WARNING("It is closed. Open now: [zombie_city_open_names()]."))

// Hurt raiders may leave; their wounds travel with them.
/obj/structure/region_gate/raid_exit/zombie_city/travel_refusal(mob/living/human/H)
	if(!zombie_city_evac_open(src)) return "This evacuation point is closed. Open now: [zombie_city_open_names()]."
	var/reason = ..()
	if(reason == "You are too hurt to make the journey." && H.stat == CONSCIOUS)
		return null
	return reason

/obj/structure/region_gate/raid_exit/zombie_city/travel(mob/living/human/H)
	if(!istype(H) || (H in waiting)) return
	var/reason = travel_refusal(H)
	if(reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	waiting += H
	H.visible_message(SPAN_NOTICE("[H] signals for evacuation."), SPAN_NOTICE("You signal for evacuation. Hold this position."))
	var/ok = do_after(H, ZOMBIE_CITY_EVAC_WAIT, src, needhand = FALSE)
	if(waiting) waiting -= H
	if(!ok)
		to_chat(H, SPAN_WARNING("You left the evacuation point."))
		return
	..()

#undef ZOMBIE_CITY_EVAC_OPEN
#undef ZOMBIE_CITY_EVAC_TURN
#undef ZOMBIE_CITY_EVAC_WAIT
