// Services through walls: power cables and pipes in a chase.
//
// A player-built wall can carry one power cable and one pipe run inside it.
// First cut a chase: a chisel or a pickaxe on the wall, not on harm intent
// (a pickaxe for stone, brick and concrete, whose faces a chisel carves). It
// takes longer in harder walls and costs the wall a tenth of its strength.
// - A cable coil on a chased wall lays a straight cable through it, in the
//   direction you face. It joins cables on either side like any other.
// - A wrench on a chased wall slides the clay or lead water pipe, factory pipe
//   or sewer pipe on your own tile into the wall. Build the pipe beside the
//   wall first, then push it in; it joins its neighbours by adjacency as before.
// What runs inside shows when the wall is examined. When the wall breaks, the
// cable snaps and the pipe bursts.
//
// Floor sleeves carry pipes between levels, the way cable risers carry power.
// Set one sleeve on a tile and another at the same spot on the level above or
// below. Factory pipes on the two tiles join one network, both ways, since a
// pump drives them. Aqueduct water and sewage only fall: a water pipe or drain
// over a sleeve feeds the piece under the sleeve below, never the other way.
// To lift water a level, pump it in a factory pipe or fill a cistern above.
// Nothing is saved for the pairing; it is read from where the sleeves stand.

#define SERVICE_CHASE_SOFT_TIME 60
#define SERVICE_CHASE_HARD_TIME 150

/obj/covers
	var/service_chase = FALSE

/proc/building_service_hard_wall(obj/covers/C)
	return building_masonry(C.material) || (lowertext("[C.material]") in list("steel", "iron"))

// The pipe pieces a chase can hold.
/proc/building_service_pipe(obj/O)
	if (istype(O, /obj/structure/aqueduct/pipe) || istype(O, /obj/structure/fluid_pipe))
		return TRUE
	if (istype(O, /obj/structure/sewer_piece) && !istype(O, /obj/structure/sewer_piece/drain) && !istype(O, /obj/structure/sewer_piece/cesspit))
		return TRUE
	return FALSE

/obj/covers/proc/service_cable()
	return locate(/obj/structure/cable) in get_turf(src)

/obj/covers/proc/service_pipe()
	for (var/obj/O in get_turf(src))
		if (building_service_pipe(O))
			return O
	return null

// Handles a service tool used on a wall. TRUE when it took the action.
/obj/covers/proc/building_service_attackby(obj/item/W, mob/living/user)
	if (!wall || incomplete || !ishuman(user))
		return FALSE
	// Straw, cloth or wool lines the wall against the cold (building_insulation.dm).
	if (user.a_intent != I_HARM && building_lining_kind(W))
		building_line_wall(W, user)
		return TRUE
	if (!service_chase)
		if ((is_tool(W, TOOL_CHISEL) || is_tool(W, TOOL_PICKAXE)) && user.a_intent != I_HARM)
			cut_service_chase(W, user)
			return TRUE
		if (istype(W, /obj/item/stack/cable_coil))
			to_chat(user, SPAN_WARNING("Cut a chase in \the [src] first: a chisel or a pickaxe, not on harm intent."))
			return TRUE
		return FALSE
	if (istype(W, /obj/item/stack/cable_coil))
		fit_service_cable(W, user)
		return TRUE
	if (is_tool(W, TOOL_WRENCH) && user.a_intent != I_HARM)
		fit_service_pipe(user)
		return TRUE
	return FALSE

/obj/covers/proc/cut_service_chase(obj/item/W, mob/living/user)
	var/hard = building_service_hard_wall(src)
	if (hard && !is_tool(W, TOOL_PICKAXE))
		to_chat(user, SPAN_WARNING("A chisel only scratches [src]. Cut the chase with a pickaxe."))
		return
	user.visible_message(SPAN_NOTICE("[user] starts cutting a chase into \the [src]."), SPAN_NOTICE("You start cutting a chase into \the [src] for cables and pipes."))
	if (!do_after(user, hard ? SERVICE_CHASE_HARD_TIME : SERVICE_CHASE_SOFT_TIME, src) || QDELETED(src) || service_chase)
		return
	service_chase = TRUE
	maxhealth = max(1, round(maxhealth * 0.9))
	health = min(health, maxhealth)
	user.visible_message(SPAN_NOTICE("[user] cuts a chase into \the [src]."), SPAN_NOTICE("You cut a chase into \the [src]. A cable coil or a pipe beside it can now go inside."))

/obj/covers/proc/fit_service_cable(obj/item/stack/cable_coil/coil, mob/living/user)
	var/dirn = get_dir(user, src)
	if (!(dirn in cardinal) || get_dist(user, src) > 1)
		to_chat(user, SPAN_WARNING("Stand straight in front of \the [src] to run a cable through it."))
		return
	if (service_cable())
		to_chat(user, SPAN_WARNING("A cable already runs through \the [src]."))
		return
	if (coil.amount < 1)
		return
	var/obj/structure/cable/C = new /obj/structure/cable(get_turf(src))
	C.color = coil.color
	C.cable_color = coil.cable_color
	C.set_cable_shape(dirn, cable_reverse_dir(dirn))
	C.add_fingerprint(user)
	C.link_end_neighbors(user)
	C.rebuild_supply()
	coil.use(1)
	user.visible_message(SPAN_NOTICE("[user] feeds a cable through \the [src]."), SPAN_NOTICE("You feed a cable through the chase in \the [src]."))

/obj/covers/proc/fit_service_pipe(mob/living/user)
	if (get_dist(user, src) > 1 || !(get_dir(user, src) in cardinal))
		to_chat(user, SPAN_WARNING("Stand straight in front of \the [src] to push a pipe into it."))
		return
	if (service_pipe())
		to_chat(user, SPAN_WARNING("A pipe already runs through \the [src]."))
		return
	var/turf/from = get_turf(user)
	var/obj/structure/P
	for (var/obj/structure/O in from)
		if (building_service_pipe(O))
			P = O
			break
	if (!P)
		to_chat(user, SPAN_WARNING("Build the water pipe, factory pipe or sewer pipe on your own tile first, then push it into the chase."))
		return
	user.visible_message(SPAN_NOTICE("[user] starts working \the [P] into \the [src]."), SPAN_NOTICE("You start working \the [P] into the chase."))
	if (!do_after(user, 40, src) || QDELETED(src) || QDELETED(P) || P.loc != from || service_pipe())
		return
	building_service_move(P, get_turf(src))
	user.visible_message(SPAN_NOTICE("[user] fits \the [P] into \the [src]."), SPAN_NOTICE("You fit \the [P] into the chase."))

// Moves a pipe piece to T and lets both ends of its network know.
/proc/building_service_move(obj/structure/P, turf/T)
	var/turf/from = get_turf(P)
	P.forceMove(T)
	if (istype(P, /obj/structure/aqueduct))
		aqueduct_revision++
		aqueduct_update_around(from)
		aqueduct_update_around(T)
	else if (istype(P, /obj/structure/sewer_piece))
		sewer_update_around(from)
		sewer_update_around(T)
	else if (istype(P, /obj/structure/fluid_pipe))
		fluid_mark_dirty()

/obj/covers/examine(mob/user)
	..()
	if (wall && insulation_lining)
		to_chat(user, "<span class='notice'>It is lined with [insulation_lining] against the cold.</span>")
	if (!wall || !service_chase)
		return
	var/obj/structure/cable/C = service_cable()
	var/obj/P = service_pipe()
	if (!C && !P)
		to_chat(user, "<span class='notice'>An empty chase is cut into it for cables and pipes.</span>")
		return
	var/list/runs = list()
	if (C)
		runs += "a power cable"
	if (P)
		runs += P.name
	to_chat(user, "<span class='notice'>[capitalize(english_list(runs))] run[runs.len == 1 ? "s" : ""] through a chase in it.</span>")

// A wall that breaks takes what runs inside with it.
/obj/covers/Destroy()
	if (wall && service_chase && isturf(loc))
		var/turf/T = loc
		for (var/obj/structure/cable/C in T)
			visible_message(SPAN_WARNING("The cable inside \the [src] snaps!"))
			qdel(C)
		for (var/obj/structure/P in T)
			if (!building_service_pipe(P))
				continue
			visible_message(SPAN_WARNING("\The [P] inside \the [src] bursts and spills!"))
			qdel(P)
	return ..()

// ---- floor sleeves ----------------------------------------------------------

/obj/structure/floor_sleeve
	name = "floor sleeve"
	desc = "A short lined shaft through the floor. Set one here and another at the same spot on the level above or below, and the pipes on both tiles join: factory pipes both ways, water pipes and drains only downwards."
	icon = 'icons/obj/floor_sleeves.dmi'
	icon_state = "sleeve"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 2.02
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/floor_sleeve/New()
	..()
	floor_sleeve_changed(get_turf(src))

/obj/structure/floor_sleeve/on_runtime_spawn()
	..()
	floor_sleeve_changed(get_turf(src))

/obj/structure/floor_sleeve/Destroy()
	var/turf/T = get_turf(src)
	. = ..()
	floor_sleeve_changed(T)

/obj/structure/floor_sleeve/examine(mob/user)
	..()
	var/turf/T = get_turf(src)
	var/list/ends = list()
	if (floor_sleeve_link(T, TRUE))
		ends += "the level above"
	if (floor_sleeve_link(T, FALSE))
		ends += "the level below"
	if (ends.len)
		to_chat(user, SPAN_NOTICE("It meets a sleeve on [english_list(ends)]."))
	else
		to_chat(user, SPAN_WARNING("No sleeve meets it on the level above or below."))

/proc/floor_sleeve_at(turf/T)
	if (!T)
		return null
	for (var/obj/structure/floor_sleeve/S in T)
		if (!QDELETED(S))
			return S
	return null

// The turf a sleeve on T joins, on the level above (up) or below, or null.
/proc/floor_sleeve_link(turf/T, up)
	if (!floor_sleeve_at(T))
		return null
	var/level = up ? multiz_level_above(T.z) : multiz_level_below(T.z)
	if (!level || level == T.z)
		return null
	var/turf/O = locate(T.x, T.y, level)
	return floor_sleeve_at(O) ? O : null

// Pipe networks on both ends notice a sleeve set or taken away.
/proc/floor_sleeve_changed(turf/T)
	if (!T)
		return
	aqueduct_revision++
	sewer_revision++
	fluid_mark_dirty()

#undef SERVICE_CHASE_SOFT_TIME
#undef SERVICE_CHASE_HARD_TIME
