// Sewers, phase S1 (docs/river-flood.md, "Sewers"). Drain pieces laid on
// adjacent tiles form a network. A plumbed toilet next to the network sends
// its waste along it, to an outfall (a drain piece beside open water) or into
// a cesspit. A plumbed toilet with nowhere to send waste backs up onto the
// floor. Open ditches and outfalls that have carried waste lately, and
// cesspits holding any, foul wells and puddles close by.
//
// The network is walked only when a toilet is used, at most SEWER_WALK_LIMIT
// pieces, so nothing runs while nobody flushes. This only applies on
// persistence maps; elsewhere plumbing still carries waste away by itself.

#define SEWER_WALK_LIMIT 600
// How long waste carried along an open ditch or out of an outfall fouls the
// water near it.
#define SEWER_FOUL_TIME 18000
#define SEWER_DITCH_FOUL_RANGE 2
#define SEWER_OUTFALL_FOUL_RANGE 4
#define CESSPIT_FOUL_RANGE 2
#define CESSPIT_CAPACITY 40
#define CESSPIT_COMPOST_PER 10

/proc/sewers_apply()
	return map && map.persistence

// A drain or a cesspit: anything waste travels through or into.
/obj/structure/sewer_piece
	icon = 'icons/obj/sewers.dmi'
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 2.03
	not_movable = TRUE
	not_disassemblable = TRUE
	var/tmp/last_waste = -SEWER_FOUL_TIME

/obj/structure/sewer_piece/persistence_runtime_var(key)
	return key == "last_waste" || ..()

/obj/structure/sewer_piece/on_runtime_spawn()
	..()
	sewer_update_around(get_turf(src))

/obj/structure/sewer_piece/Destroy()
	var/turf/T = get_turf(src)
	. = ..()
	sewer_update_around(T, src)

/obj/structure/sewer_piece/proc/sewer_update_icon()
	return

// TRUE while it has carried waste recently.
/obj/structure/sewer_piece/proc/recently_fouled()
	return world.time - last_waste < SEWER_FOUL_TIME

// Tiles away within which this piece fouls a well, or 0.
/obj/structure/sewer_piece/proc/foul_range()
	return 0

/proc/sewer_piece_at(turf/T, obj/structure/sewer_piece/except)
	if (!T)
		return null
	for (var/obj/structure/sewer_piece/P in T)
		if (P != except && !QDELETED(P))
			return P
	return null

/proc/sewer_update_around(turf/T, obj/structure/sewer_piece/except)
	if (!T)
		return
	var/obj/structure/sewer_piece/P = sewer_piece_at(T, except)
	if (P)
		P.sewer_update_icon()
	for (var/d in cardinal)
		P = sewer_piece_at(get_step(T, d), except)
		if (P)
			P.sewer_update_icon()

// ---- drains ------------------------------------------------------------

/obj/structure/sewer_piece/drain
	name = "drain"
	icon_state = "stone_drain0"
	var/junction_prefix = "stone_drain"
	// Open channels foul water near them while they carry waste.
	var/open_channel = FALSE

/obj/structure/sewer_piece/drain/ditch
	name = "drain ditch"
	desc = "An open ditch dug to carry waste and water away. It needs to run to a river, a lake or a cesspit."
	icon_state = "ditch0"
	junction_prefix = "ditch"
	open_channel = TRUE

/obj/structure/sewer_piece/drain/stone
	name = "stone drain"
	desc = "A drain channel covered with stone slabs. Covered drains keep waste away from wells; it needs to run to a river, a lake or a cesspit."
	icon_state = "stone_drain0"
	junction_prefix = "stone_drain"
	not_disassemblable = FALSE

// The open water this drain spills into, or null.
/obj/structure/sewer_piece/drain/proc/outfall_dir()
	var/turf/T = get_turf(src)
	if (!T)
		return 0
	for (var/d in cardinal)
		if (istype(get_step(T, d), /turf/floor/beach/water))
			return d
	return 0

/obj/structure/sewer_piece/drain/sewer_update_icon()
	var/turf/T = get_turf(src)
	if (!T)
		return
	var/junction = 0
	for (var/d in cardinal)
		if (sewer_piece_at(get_step(T, d)))
			junction |= d
	icon_state = "[junction_prefix][junction]"
	overlays.Cut()
	var/d = outfall_dir()
	if (d)
		overlays += image(icon, "outfall", dir = d)

/obj/structure/sewer_piece/drain/foul_range()
	if (outfall_dir())
		return SEWER_OUTFALL_FOUL_RANGE
	return open_channel ? SEWER_DITCH_FOUL_RANGE : 0

/obj/structure/sewer_piece/drain/examine(mob/user, distance = -1)
	. = ..()
	if (!. || get_dist(src, user) > 2)
		return
	if (outfall_dir())
		to_chat(user, SPAN_NOTICE("It spills into the water here."))
	if (recently_fouled() && foul_range())
		to_chat(user, SPAN_WARNING("It stinks of fresh sewage."))

// ---- cesspits -------------------------------------------------------------

/obj/structure/sewer_piece/cesspit
	name = "cesspit"
	desc = "A deep pit lined with planks that collects waste from the drains and privies around it. Dig it out with a shovel when it fills; the night soil makes compost."
	icon_state = "cesspit0"
	var/waste = 0

/obj/structure/sewer_piece/cesspit/sewer_update_icon()
	icon_state = "cesspit[waste <= 0 ? 0 : (waste >= CESSPIT_CAPACITY ? 3 : (waste * 2 >= CESSPIT_CAPACITY ? 2 : 1))]"

/obj/structure/sewer_piece/cesspit/proc/is_full()
	return waste >= CESSPIT_CAPACITY

/obj/structure/sewer_piece/cesspit/proc/take_waste()
	if (is_full())
		return FALSE
	waste++
	sewer_update_icon()
	return TRUE

/obj/structure/sewer_piece/cesspit/foul_range()
	return CESSPIT_FOUL_RANGE

/obj/structure/sewer_piece/cesspit/recently_fouled()
	return waste > 0

/obj/structure/sewer_piece/cesspit/examine(mob/user, distance = -1)
	. = ..()
	if (!. || get_dist(src, user) > 2)
		return
	if (waste <= 0)
		to_chat(user, SPAN_NOTICE("It is empty."))
	else if (is_full())
		to_chat(user, SPAN_WARNING("It is full to the brim. Dig it out with a shovel before anything else drains here."))
	else
		to_chat(user, SPAN_NOTICE("It is [round(waste * 100 / CESSPIT_CAPACITY)]% full."))

/obj/structure/sewer_piece/cesspit/attackby(obj/item/I, mob/living/user)
	if (!istype(I, /obj/item/weapon/material/shovel))
		return ..()
	if (waste <= 0)
		to_chat(user, SPAN_NOTICE("\The [src] is empty."))
		return
	user.visible_message(SPAN_NOTICE("[user] starts digging the night soil out of \the [src]."), SPAN_NOTICE("You start digging the night soil out of \the [src]."))
	playsound(src, 'sound/effects/shovelling.ogg', 100, TRUE)
	if (!do_after(user, 100, src) || waste <= 0)
		return
	var/compost = round(waste / CESSPIT_COMPOST_PER)
	for (var/i in 1 to compost)
		new /obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer(get_turf(user))
	waste = 0
	sewer_update_icon()
	user.visible_message(SPAN_NOTICE("[user] empties \the [src]."), SPAN_NOTICE("You empty \the [src][compost ? " and pile up the night soil as compost" : ""]."))

// ---- network -----------------------------------------------------------

// Where waste put in at turf T goes: an outfall drain, a cesspit with room,
// or null. Pieces on T or next to it start the walk. Every open ditch and
// outfall the waste passes is marked as carrying it.
/proc/sewer_carry_waste(turf/T)
	if (!T)
		return null
	var/list/queue = list()
	var/list/seen = list()
	for (var/obj/structure/sewer_piece/P in T)
		queue += P
		seen[P] = TRUE
	for (var/d in cardinal)
		var/turf/N = get_step(T, d)
		if (!N)
			continue
		for (var/obj/structure/sewer_piece/P in N)
			if (!seen[P])
				queue += P
				seen[P] = TRUE
	var/obj/structure/sewer_piece/cesspit/pit = null
	var/obj/structure/sewer_piece/drain/outfall = null
	var/i = 1
	while (i <= queue.len && i <= SEWER_WALK_LIMIT)
		var/obj/structure/sewer_piece/P = queue[i++]
		if (istype(P, /obj/structure/sewer_piece/cesspit))
			var/obj/structure/sewer_piece/cesspit/C = P
			if (!pit && !C.is_full())
				pit = C
			// Waste settles in a pit; it does not flow on through it.
			continue
		var/obj/structure/sewer_piece/drain/D = P
		if (D.outfall_dir())
			outfall = D
			break
		var/turf/PT = get_turf(D)
		for (var/d in cardinal)
			var/turf/N = get_step(PT, d)
			if (!N)
				continue
			for (var/obj/structure/sewer_piece/Q in N)
				if (!seen[Q])
					seen[Q] = TRUE
					queue += Q
	if (outfall)
		for (var/obj/structure/sewer_piece/drain/D in queue)
			if (D.open_channel)
				D.last_waste = world.time
		outfall.last_waste = world.time
		return outfall
	if (pit)
		pit.take_waste()
		for (var/obj/structure/sewer_piece/drain/D in queue)
			if (D.open_channel)
				D.last_waste = world.time
		return pit
	return null

// TRUE when sewage close to A fouls its water.
/proc/sewer_fouls_near(atom/A)
	for (var/obj/structure/sewer_piece/P in range(max(SEWER_OUTFALL_FOUL_RANGE, SEWER_DITCH_FOUL_RANGE, CESSPIT_FOUL_RANGE), A))
		var/r = P.foul_range()
		if (r && get_dist(P, A) <= r && P.recently_fouled())
			return TRUE
	return FALSE

// ---- fixtures ------------------------------------------------------------

// Whether this plumbed fixture's waste is carried away from where it stands.
/obj/structure/toilet/proc/drains_away()
	if (!is_plumbed())
		return FALSE
	if (!sewers_apply())
		return TRUE
	var/turf/T = get_turf(src)
	if (sewer_piece_at(T))
		return TRUE
	for (var/d in cardinal)
		if (sewer_piece_at(get_step(T, d)))
			return TRUE
	return FALSE

// Send waste V down a plumbed fixture. Returns TRUE when it went; otherwise
// the fixture backs up and V is left on the floor.
/obj/structure/toilet/proc/flush_waste(obj/item/V)
	if (!sewers_apply() || sewer_carry_waste(get_turf(src)))
		qdel(V)
		return TRUE
	V.forceMove(get_turf(src))
	visible_message(SPAN_WARNING("\The [src] gurgles and backs up: its waste has nowhere to drain."))
	return FALSE

/obj/structure/toilet/examine(mob/user, distance = -1)
	. = ..()
	if (. && is_plumbed() && sewers_apply() && get_dist(src, user) <= 2 && !drains_away())
		to_chat(user, SPAN_WARNING("No drain runs from it. Lay a drain from it to a river, a lake or a cesspit."))

// ---- digging ---------------------------------------------------------------

/obj/item/weapon/material/shovel/proc/shovel_dig_sewer(mob/user, turf/floor/TB, cesspit)
	if (!istype(TB) || istype(TB, /turf/floor/wood) || istype(TB, /turf/floor/wood_broken) || istype(TB, /turf/floor/ship) || istype(TB, /turf/floor/carpet) || istype(TB, /turf/floor/broken_floor) || istype(TB, /turf/floor/plating/cobblestone) || istype(TB, /turf/floor/plating/concrete) || istype(TB, /turf/floor/plating/stone_old))
		to_chat(user, SPAN_WARNING("You can't dig that here."))
		return
	if (locate(/obj/structure/multiz) in TB)
		to_chat(user, SPAN_NOTICE("There is a tunnel entrance here!"))
		return
	if (sewer_piece_at(TB))
		to_chat(user, SPAN_WARNING("There is already a drain or a cesspit here."))
		return
	var/what = cesspit ? "a cesspit" : "a drain ditch"
	user.visible_message(SPAN_NOTICE("[user] starts digging [what]."), SPAN_NOTICE("You start digging [what]."), SPAN_NOTICE("You hear the ground being dug nearby."))
	playsound(src, 'sound/effects/shovelling.ogg', 100, TRUE)
	if (!do_after(user, cesspit ? 150 : 40, src) || sewer_piece_at(TB))
		return
	if (cesspit)
		new /obj/structure/sewer_piece/cesspit(TB)
	else
		new /obj/structure/sewer_piece/drain/ditch(TB)
	to_chat(user, SPAN_NOTICE("You finish digging [what]."))

#undef SEWER_WALK_LIMIT
#undef SEWER_FOUL_TIME
#undef SEWER_DITCH_FOUL_RANGE
#undef SEWER_OUTFALL_FOUL_RANGE
#undef CESSPIT_FOUL_RANGE
#undef CESSPIT_CAPACITY
#undef CESSPIT_COMPOST_PER
