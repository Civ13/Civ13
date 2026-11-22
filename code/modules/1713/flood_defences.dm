// Stone and Classical flood defences (docs/river-flood.md, "Defences").
//
// - Stilt platforms and stone plinths raise what stands on a tile above the
//   water: floodwater on that tile is shallower by their height.
// - A timber sluice gate in a levee holds the river back like a half-wall
//   while it is shut, and lets it through, onto fields for their silt, when
//   it is drawn up.
// - A shaduf or an Archimedes screw at the edge of a hollow lifts its pooled
//   water out over the rim by hand.
// - A river gauge post shows how high the river stands against its banks, and
//   the highest it has stood lately.
// - A plastered cistern stores rain, from the sky over it and from gutters on
//   the roofs around it, for the dry months.
//
// Platforms set a turf var, gates mark the flood window like a half-wall,
// lifts work while someone works them. Only cisterns tick, like rain barrels.

#define STILT_RAISE 2
#define PLINTH_RAISE 1
#define SLUICE_CREST 1.5
#define CISTERN_CAPACITY 2000
// Water a minute of rain puts in from the open sky over it, and from each
// roofed tile within reach of its gutters.
#define CISTERN_OPEN_RATE 10
#define CISTERN_PER_ROOF 3
#define CISTERN_GUTTER_RANGE 2
#define CISTERN_ROOF_RECOUNT 3000

// Levels a platform on this tile lifts what stands on it; rebuilt from the
// platforms as they are built or load, so never saved.
/turf/var/tmp/flood_raise = 0

/proc/flood_raise_update(turf/T)
	if (!istype(T))
		return
	var/raise = 0
	for (var/obj/structure/flood_platform/P in T)
		if (!QDELETED(P) && P.raise > raise)
			raise = P.raise
	T.flood_raise = raise

// ---- platforms ---------------------------------------------------------------

/obj/structure/flood_platform
	icon = 'icons/obj/flood_defences.dmi'
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 2.02
	not_movable = TRUE
	not_disassemblable = FALSE
	var/raise = PLINTH_RAISE

/obj/structure/flood_platform/New()
	..()
	flood_raise_update(loc)

/obj/structure/flood_platform/on_runtime_spawn()
	..()
	flood_raise_update(loc)

/obj/structure/flood_platform/Destroy()
	var/turf/T = loc
	. = ..()
	flood_raise_update(T)

/obj/structure/flood_platform/examine(mob/user, distance = -1)
	. = ..()
	if (. && get_dist(src, user) <= 2)
		to_chat(user, SPAN_NOTICE("Whatever stands on it stays dry until a flood rises [raise == 1 ? "a level" : "[raise] levels"] above the ground."))

/obj/structure/flood_platform/stilts
	name = "stilt platform"
	desc = "A plank floor raised on wooden posts above flood-prone ground. Build a hut on it and the river can rise to your knees outside while the floor stays dry."
	icon_state = "stilts"
	raise = STILT_RAISE

/obj/structure/flood_platform/plinth
	name = "stone plinth"
	desc = "A raised foundation of dressed stone. Walls and floors set on it stay dry through the smaller floods."
	icon_state = "plinth"
	raise = PLINTH_RAISE

// ---- sluice gates -------------------------------------------------------------

/obj/structure/sluice_gate
	name = "sluice gate"
	desc = "Timber boards in a frame, set in a gap in a levee. Shut, it holds the river back like the bank around it; drawn up, it lets floodwater through onto the fields behind, to leave its silt there. A lever's cord can draw it up and lower it."
	icon = 'icons/obj/flood_defences.dmi'
	icon_state = "sluice_gate"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	layer = 3.1
	not_movable = TRUE
	not_disassemblable = FALSE
	var/open = FALSE
	var/flood_crest = SLUICE_CREST

/obj/structure/sluice_gate/New()
	..()
	sluice_update()

/obj/structure/sluice_gate/on_runtime_spawn()
	..()
	sluice_update()

/obj/structure/sluice_gate/Destroy()
	if (isturf(loc))
		flood_ground_changed(loc)
	return ..()

/obj/structure/sluice_gate/proc/sluice_update()
	icon_state = open ? "sluice_gate_open" : "sluice_gate"
	density = !open
	if (isturf(loc))
		flood_ground_changed(loc)

// The height it holds water back on its tile: nothing while drawn up.
/obj/structure/sluice_gate/proc/crest()
	return open ? 0 : flood_crest

/obj/structure/sluice_gate/proc/set_open(state)
	if (open == state)
		return FALSE
	open = state
	sluice_update()
	return TRUE

/obj/structure/sluice_gate/attack_hand(mob/living/user)
	if (!istype(user))
		return ..()
	var/what = open ? "lowering the boards of" : "drawing up the boards of"
	user.visible_message(SPAN_NOTICE("[user] starts [what] \the [src]."), SPAN_NOTICE("You start [what] \the [src]."))
	if (!do_after(user, 30, src))
		return
	set_open(!open)
	user.visible_message(SPAN_NOTICE("[user] [open ? "opens" : "shuts"] \the [src]."), SPAN_NOTICE("You [open ? "open" : "shut"] \the [src].[open ? " Floodwater can pass." : " It holds the river back."]"))

/obj/structure/sluice_gate/examine(mob/user, distance = -1)
	. = ..()
	if (. && get_dist(src, user) <= 2)
		to_chat(user, SPAN_NOTICE(open ? "It is open: floodwater passes through." : "It is shut: it holds the river back as high as an earth bank."))

// ---- water lifts --------------------------------------------------------------

/obj/structure/water_lift
	icon = 'icons/obj/flood_defences.dmi'
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	layer = 3.1
	not_movable = TRUE
	not_disassemblable = FALSE
	// Tile-levels of a hollow's water lifted out per working.
	var/lift = 0.5
	var/work_time = 30
	var/use_state = null
	var/tmp/busy = FALSE

/obj/structure/water_lift/persistence_runtime_var(key)
	return key == "busy" || ..()

// The hollow it stands in and can empty, or 0: it must stand on the edge,
// beside ground outside the hollow to pour the water onto.
/obj/structure/water_lift/proc/lift_hollow()
	var/turf/T = get_turf(src)
	if (!T || !map)
		return 0
	var/datum/river_flood/F = map.river_flood()
	if (!F || T.z != F.z_level || !F.hollow_count)
		return 0
	var/h = F.hollow_at(T.x, T.y)
	if (!h)
		return 0
	for (var/d in cardinal)
		var/turf/N = get_step(T, d)
		if (N && F.hollow_at(N.x, N.y) != h)
			return h
	return 0

// Lift one load out: the water lifted, 0 when there is none to lift.
/obj/structure/water_lift/proc/lift_once()
	var/h = lift_hollow()
	if (!h)
		return 0
	var/datum/river_flood/F = map.river_flood()
	var/taken = min(lift, F.hollow_volume[h])
	if (taken <= 0)
		return 0
	F.hollow_volume[h] -= taken
	if (F.hollow_volume[h] < 0.01)
		F.hollow_volume[h] = 0
	F.hollow_level[h] = F.hollow_level_for(h, F.hollow_volume[h])
	return taken

/obj/structure/water_lift/attack_hand(mob/living/user)
	if (!istype(user))
		return ..()
	if (busy)
		to_chat(user, SPAN_WARNING("Someone is already working \the [src]."))
		return
	var/h = lift_hollow()
	if (!h)
		to_chat(user, SPAN_WARNING("There is no pooled water here to lift. Set \the [src] on the edge of a hollow that floods, beside the ground outside it."))
		return
	var/datum/river_flood/F = map.river_flood()
	if (F.hollow_volume[h] <= 0)
		to_chat(user, SPAN_NOTICE("The hollow is dry."))
		return
	busy = TRUE
	if (use_state)
		icon_state = use_state
	to_chat(user, SPAN_NOTICE("You start lifting water out of the hollow with \the [src]."))
	var/total = 0
	while (do_after(user, work_time, src))
		var/taken = lift_once()
		if (taken <= 0)
			break
		total += taken
	busy = FALSE
	icon_state = initial(icon_state)
	if (total > 0)
		to_chat(user, SPAN_NOTICE("You pour the water out over the rim.[F.hollow_volume[h] <= 0 ? " The hollow is dry." : ""]"))

/obj/structure/water_lift/shaduf
	name = "shaduf"
	desc = "A long pole swung on an upright post, with a bucket on one end and a counterweight on the other. Set on the edge of a flooded hollow, it lifts the water out over the rim, one bucket at a time."
	icon_state = "shaduf"
	use_state = "shaduf_use"
	lift = 0.5

/obj/structure/water_lift/archimedes_screw
	name = "Archimedes screw"
	desc = "A wooden screw in a sealed barrel, laid at a slant and turned by a crank. Set on the edge of a flooded hollow, it lifts water out over the rim far faster than a bucket. Beside a treadwheel, horse gin, mill wheel or windmill, or on a line shaft, it turns on its own and drains the hollow while it is driven."
	icon_state = "archimedes_screw"
	use_state = "archimedes_screw_use"
	lift = 1.5
	drive_draw = 1
	var/tmp/next_lift = 0

/obj/structure/water_lift/archimedes_screw/persistence_runtime_var(key)
	return key == "next_lift" || ..()

/obj/structure/water_lift/archimedes_screw/New()
	..()
	processing_objects |= src

/obj/structure/water_lift/archimedes_screw/after_load()
	..()
	processing_objects |= src

/obj/structure/water_lift/archimedes_screw/on_runtime_spawn()
	..()
	processing_objects |= src

/obj/structure/water_lift/archimedes_screw/Destroy()
	processing_objects -= src
	return ..()

// One driven turn: lifts a load when a drive turns it and its hollow holds
// water; TRUE when it lifted. Undriven or dry, it looks again in 30 s.
/obj/structure/water_lift/archimedes_screw/proc/driven_lift()
	// The hollow is looked up first: it is cheap, and most screws stand dry.
	var/h = (anchored && !busy) ? lift_hollow() : 0
	var/datum/river_flood/F = h ? map.river_flood() : null
	var/factor = (F && F.hollow_volume[h] > 0) ? mechanical_drive_factor(src) : 1
	if (factor >= 1 || lift_once() <= 0)
		next_lift = world.time + 300
		if (icon_state != initial(icon_state))
			icon_state = initial(icon_state)
		return FALSE
	icon_state = use_state
	next_lift = world.time + round(work_time * factor * 2)
	return TRUE

/obj/structure/water_lift/archimedes_screw/process_interval(configured_seconds = 2)
	if (QDELETED(src))
		return PROCESS_KILL
	if (world.time >= next_lift)
		driven_lift()

// ---- river gauge ---------------------------------------------------------------

/obj/structure/river_gauge
	name = "river gauge"
	desc = "A tall post driven in by the river, painted with level marks, to read how high the water stands against the banks."
	icon = 'icons/obj/flood_defences.dmi'
	icon_state = "river_gauge"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	layer = 3.1
	not_movable = TRUE
	not_disassemblable = FALSE

// The reach whose banks this post reads, or 0: it must stand within two
// tiles of the river's water.
/obj/structure/river_gauge/proc/gauge_reach(datum/river_flood/F)
	var/turf/T = get_turf(src)
	if (!T || !F || T.z != F.z_level)
		return 0
	var/turf/water = locate(/turf/floor/beach/water) in range(2, T)
	if (!water)
		return 0
	return F.reach_at(T.x, T.y) || F.reach_at(water.x, water.y)

// What the marks show, or null when it stands by no river.
/obj/structure/river_gauge/proc/reading()
	var/datum/river_flood/F = map ? map.river_flood() : null
	var/r = gauge_reach(F)
	if (!r)
		return null
	var/turf/T = get_turf(src)
	var/bank = F.effective_threshold(T)
	if (isnull(bank))
		bank = terrain_height_at(T)
	var/gap = F.stage[r] - bank
	. = list()
	if (gap > 0)
		. += "The river is over its banks here, [gap] level\s above their top."
	else if (gap > -1)
		. += "The river stands close under the top of its banks."
	else
		. += "The river stands [-gap] level\s below the top of its banks."
	var/peak_gap = F.peak[r] - bank
	if (peak_gap > 0)
		. += "The highest mark of the last floods is [peak_gap] level\s above the top of the banks."
	else
		. += "No flood has topped the banks here lately."

/obj/structure/river_gauge/examine(mob/user, distance = -1)
	. = ..()
	if (!. || get_dist(src, user) > 2)
		return
	var/list/lines = reading()
	if (!lines)
		to_chat(user, SPAN_WARNING("It stands by no river. Drive it in within two tiles of a river's water."))
		return
	for (var/line in lines)
		to_chat(user, SPAN_NOTICE(line))

// ---- cisterns ------------------------------------------------------------------

/obj/structure/reagent_dispensers/cistern
	name = "cistern"
	desc = "A stone tank lined with lime plaster to hold water. Rain falling on it, and on the roofs around it through their gutters, runs in and keeps for the dry months. Draw from it with a bucket."
	icon = 'icons/obj/flood_defences.dmi'
	icon_state = "cistern0"
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = FALSE
	density = TRUE
	max_capacity = CISTERN_CAPACITY
	var/tmp/collection_seconds = 0
	var/tmp/last_collection_tick = 0
	var/tmp/roofs = 0
	var/tmp/roofs_counted = -CISTERN_ROOF_RECOUNT

/obj/structure/reagent_dispensers/cistern/persistence_runtime_var(key)
	return (key in list("collection_seconds", "last_collection_tick", "roofs", "roofs_counted")) || ..()

/obj/structure/reagent_dispensers/cistern/New()
	..()
	last_collection_tick = world.time
	processing_objects |= src
	cistern_update_icon()

/obj/structure/reagent_dispensers/cistern/on_runtime_spawn()
	..()
	processing_objects |= src
	cistern_update_icon()

/obj/structure/reagent_dispensers/cistern/Destroy()
	processing_objects -= src
	return ..()

/obj/structure/reagent_dispensers/cistern/proc/cistern_update_icon()
	var/fill = reagents ? reagents.total_volume / max(1, reagents.maximum_volume) : 0
	icon_state = "cistern[fill <= 0 ? 0 : (fill >= 0.9 ? 3 : (fill >= 0.4 ? 2 : 1))]"

/obj/structure/reagent_dispensers/cistern/on_reagent_change()
	..()
	cistern_update_icon()

// Roofs within reach of its gutters, counted now and then.
/obj/structure/reagent_dispensers/cistern/proc/roof_count()
	if (world.time - roofs_counted < CISTERN_ROOF_RECOUNT)
		return roofs
	roofs_counted = world.time
	roofs = 0
	for (var/turf/T in range(CISTERN_GUTTER_RANGE, src))
		if (locate(/obj/roof) in T)
			roofs++
	return roofs

// Water a minute it takes in now.
/obj/structure/reagent_dispensers/cistern/proc/collection_rate()
	var/turf/T = loc
	if (!isturf(T))
		return 0
	var/falling = weather_look_at(T)
	if (!(findtext(falling, "rain") || falling == "monsoon") || weather_heat_at(T) || get_temp(src) <= 0)
		return 0
	. = roof_count() * CISTERN_PER_ROOF
	var/area/A = get_area(T)
	if (A && A.location == AREA_OUTSIDE && !(locate(/obj/roof) in T))
		. += CISTERN_OPEN_RATE

/obj/structure/reagent_dispensers/cistern/process_interval(configured_seconds = 2)
	if (QDELETED(src) || !isturf(loc))
		return PROCESS_KILL
	var/elapsed = min(2, max(0, configured_seconds), max(0, (world.time - last_collection_tick) / 10))
	last_collection_tick = world.time
	collection_seconds += elapsed
	if (collection_seconds < 60)
		return
	collection_seconds = 0
	collect_minute()

// One minute of rain into the tank.
/obj/structure/reagent_dispensers/cistern/proc/collect_minute()
	if (!reagents || reagents.total_volume >= reagents.maximum_volume)
		return 0
	var/rate = collection_rate()
	if (!rate)
		return 0
	rate = min(rate, reagents.maximum_volume - reagents.total_volume)
	reagents.add_reagent("water", rate)
	return rate

/obj/structure/reagent_dispensers/cistern/examine(mob/user, distance = -1)
	. = ..()
	if (get_dist(src, user) > 2 || !reagents)
		return
	to_chat(user, SPAN_NOTICE("It holds [round(reagents.total_volume)] of [reagents.maximum_volume] units. In rain it takes in [CISTERN_OPEN_RATE] a minute from the open sky and [CISTERN_PER_ROOF] for each roofed tile within [CISTERN_GUTTER_RANGE] tiles."))

#undef CISTERN_CAPACITY
#undef CISTERN_OPEN_RATE
#undef CISTERN_PER_ROOF
#undef CISTERN_GUTTER_RANGE
#undef CISTERN_ROOF_RECOUNT
#undef STILT_RAISE
#undef PLINTH_RAISE
#undef SLUICE_CREST
