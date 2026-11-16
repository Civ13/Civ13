// Floor drains: a grated drain set in a floor (sewers.dm, docs/hygiene.md).
//
// A floor drain is a drain piece: it joins drains, sewers, cesspits and floor
// sleeves beside or under it like any other, and in a hollow it takes the
// rainwater away. What it adds is the floor around it:
// - Water spilt on it or beside it (a puddle) runs away, and washes any
//   blood, vomit, urine or oil on that tile down with it.
// - Blood, vomit, urine, mucus or oil that lands on the drain itself goes
//   straight down.
// Anything foul it takes is carried like a toilet's waste: it fouls the
// outfall's water downstream or fills a cesspit, and now and then a drain on
// the way silts up. A floor drain chokes on hair and scum now and then;
// pull it clear by hand.
// It only works while its drain runs somewhere: to an outfall that is not
// backed up, or a cesspit with room. Off settlement maps it always drains.

/obj/structure/sewer_piece/drain/floor
	name = "floor drain"
	desc = "A stone drain set in the floor, with holes for water to run away. Spilt water, blood and slops go down it to the drain it joins: lay a drain from it to a river, a lake or a cesspit, or set it over a floor sleeve to a drain below."
	icon = 'icons/obj/floor_drains.dmi'
	icon_state = "floor_drain"
	junction_prefix = "floor_drain"
	layer = 2.04
	not_disassemblable = FALSE
	inlet_rate = 1
	clog_chance = 1

/obj/structure/sewer_piece/drain/floor/sewer_update_icon()
	icon_state = clogged ? "floor_drain_clogged" : "floor_drain"
	overlays.Cut()

/obj/structure/sewer_piece/drain/floor/attack_hand(mob/living/user)
	if (!clogged || !ishuman(user))
		return ..()
	user.visible_message(SPAN_NOTICE("[user] starts pulling the muck out of \the [src]."), SPAN_NOTICE("You start pulling the hair and scum out of \the [src]."))
	if (!do_after(user, 30, src) || !clogged)
		return
	set_clogged(FALSE)
	to_chat(user, SPAN_NOTICE("You clear \the [src]. Water runs down it again."))

/obj/structure/sewer_piece/drain/floor/examine(mob/user, distance = -1)
	. = ..()
	if (!. || get_dist(src, user) > 2)
		return
	if (clogged)
		to_chat(user, SPAN_WARNING("It is choked with hair and scum. Pull it clear by hand."))
	else if (!floor_drain_route(src))
		to_chat(user, SPAN_WARNING("Nothing runs from it, or what it runs to is full or backed up. Lay a drain from it to a river, a lake or a cesspit."))

// ---- where it goes ----------------------------------------------------------

/datum/floor_drain_route
	var/found = FALSE

/datum/floor_drain_route/proc/visit(obj/structure/sewer_piece/P)
	if (istype(P, /obj/structure/sewer_piece/cesspit))
		var/obj/structure/sewer_piece/cesspit/C = P
		if (!C.is_full())
			found = TRUE
			return TRUE
		return FALSE
	var/obj/structure/sewer_piece/drain/D = P
	if (istype(D) && !D.clogged && D.outfall_dir() && !D.backflowing() && world.time >= D.full_until)
		found = TRUE
		return TRUE
	return FALSE

// Whether water put down drain D gets away.
/proc/floor_drain_route(obj/structure/sewer_piece/drain/floor/D)
	if (!D || QDELETED(D) || D.clogged)
		return FALSE
	if (!sewers_apply())
		return TRUE
	var/datum/floor_drain_route/R = new
	sewer_walk(list(D), CALLBACK(R, /datum/floor_drain_route/proc/visit))
	return R.found

// A working floor drain on T or right beside it, or null.
/proc/floor_drain_near(turf/T)
	if (!T)
		return null
	for (var/turf/N in list(T) + floor_drain_cardinals(T))
		for (var/obj/structure/sewer_piece/drain/floor/D in N)
			if (floor_drain_route(D))
				return D
	return null

/proc/floor_drain_cardinals(turf/T)
	. = list()
	for (var/d in cardinal)
		var/turf/N = get_step(T, d)
		if (N)
			. += N

// ---- what it takes ------------------------------------------------------------

// Whether a stain is a liquid that runs down a drain.
/proc/floor_drain_liquid(obj/effect/decal/cleanable/C)
	if (istype(C, /obj/effect/decal/cleanable/blood))
		return !istype(C, /obj/effect/decal/cleanable/blood/gibs) && !istype(C, /obj/effect/decal/cleanable/blood/writing)
	return istype(C, /obj/effect/decal/cleanable/vomit) || istype(C, /obj/effect/decal/cleanable/urine) || istype(C, /obj/effect/decal/cleanable/mucus)

// Washes the liquid stains on T down drain D. Returns how many went.
/proc/floor_drain_wash_tile(turf/T, obj/structure/sewer_piece/drain/floor/D)
	. = 0
	if (!T || !D)
		return
	for (var/obj/effect/decal/cleanable/C in T)
		if (QDELETED(C) || !floor_drain_liquid(C))
			continue
		qdel(C)
		.++
	if (. && sewers_apply())
		sewer_carry_waste(get_turf(D))

// A stain that lands on a floor drain goes down it.
/proc/floor_drain_take_stain(obj/effect/decal/cleanable/C)
	if (QDELETED(C) || !isturf(C.loc))
		return
	for (var/obj/structure/sewer_piece/drain/floor/D in C.loc)
		if (floor_drain_route(D))
			floor_drain_wash_tile(C.loc, D)
			return

/obj/effect/decal/cleanable/New()
	..()
	if (isturf(loc) && floor_drain_liquid(src) && (locate(/obj/structure/sewer_piece/drain/floor) in loc))
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(floor_drain_take_stain), src), 1)

// A puddle on or beside a working floor drain runs away, and washes the stains
// on its tile down with it. Returns TRUE when it went.
/proc/floor_drain_take_puddle(obj/effect/flooding/F)
	var/turf/T = get_turf(F)
	var/obj/structure/sewer_piece/drain/floor/D = floor_drain_near(T)
	if (!D)
		return FALSE
	floor_drain_wash_tile(T, D)
	F.visible_message(SPAN_NOTICE("The water runs away down \the [D]."))
	qdel(F)
	return TRUE
