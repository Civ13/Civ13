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

// ---- bath water ---------------------------------------------------------------
//
// On settlement maps a bath's water has to go somewhere:
// - A running shower wets the floor under it each minute, unless a floor drain
//   is on or beside it, or a closed curtain hangs round it.
// - A tub turned off empties onto the floor beside it, unless a floor drain is
//   on or beside it.
// - Someone stepping out of a shower or tub that ran lately drips a little
//   puddle where they step, unless a bath mat lies there.
// The puddles run away down a floor drain like any other.

#define BATH_SPILL_GAP 600
#define BATH_DRIP_TIME 300

/obj/structure/shower/var/tmp/next_bath_spill = 0
/obj/structure/shower/var/tmp/drips_until = 0

/obj/structure/shower/persistence_runtime_var(key)
	return key == "next_bath_spill" || key == "drips_until" || ..()

/proc/bath_water_applies()
	return sewers_apply()

// Whether the bath water at S's spot has somewhere to go, or is kept in.
/obj/structure/shower/proc/bath_water_contained()
	var/turf/T = get_turf(src)
	if (floor_drain_near(T))
		return TRUE
	if (!istype(src, /obj/structure/shower/bathtub))
		for (var/obj/structure/curtain/C in T)
			if (C.opacity)
				return TRUE
	return FALSE

/proc/bath_water_puddle(turf/T, level)
	if (!istype(T, /turf/floor) || T.density)
		return null
	var/obj/effect/flooding/F = new /obj/effect/flooding(T)
	F.flood_level = level
	F.update_icon()
	return F

// A free floor tile beside a tub for its water to run onto.
/obj/structure/shower/proc/bath_spill_turf()
	var/turf/T = get_turf(src)
	for (var/d in list(dir, turn(dir, 90), turn(dir, -90), turn(dir, 180)))
		var/turf/N = get_step(T, d)
		if (!istype(N, /turf/floor) || N.density)
			continue
		var/blocked = FALSE
		for (var/obj/O in N)
			if (O.density)
				blocked = TRUE
				break
		if (!blocked)
			return N
	return null

/obj/structure/shower/proc/bath_water_running()
	drips_until = world.time + BATH_DRIP_TIME
	if (!bath_water_applies() || istype(src, /obj/structure/shower/bathtub) || world.time < next_bath_spill)
		return
	next_bath_spill = world.time + BATH_SPILL_GAP
	if (bath_water_contained())
		return
	bath_water_puddle(get_turf(src), 1)

/obj/structure/shower/proc/bath_water_turned_off()
	drips_until = world.time + BATH_DRIP_TIME
	if (!bath_water_applies() || !istype(src, /obj/structure/shower/bathtub) || bath_water_contained())
		return
	var/turf/T = bath_spill_turf()
	if (T && bath_water_puddle(T, 2))
		visible_message(SPAN_WARNING("The bathwater slops out of \the [src] across the floor. A floor drain beside it would take it away."))

/obj/structure/shower/process()
	. = ..()
	if (on)
		bath_water_running()

/obj/structure/shower/attack_hand(mob/M)
	var/was_on = on
	. = ..()
	if (was_on && !on)
		bath_water_turned_off()

// Stepping out wet drips on the floor, unless onto a bath mat.
/obj/structure/shower/Uncrossed(atom/movable/AM)
	..()
	if (!ishuman(AM) || world.time >= drips_until || !bath_water_applies())
		return
	addtimer(CALLBACK(src, PROC_REF(bath_drip), AM), 1)

/obj/structure/shower/proc/bath_drip(mob/living/human/H)
	if (QDELETED(H) || QDELETED(src))
		return
	var/turf/T = H.loc
	if (!isturf(T) || T == loc || get_dist(T, src) > 1 || bath_mat_on(T))
		return
	bath_water_puddle(T, 1)

/proc/bath_mat_on(turf/T)
	return locate(/obj/item/bath_mat) in T

/obj/item/bath_mat
	name = "bath mat"
	desc = "A thick cloth mat. Lay it beside a bath or shower and step out onto it, and the drips soak into it instead of puddling on the floor."
	icon = 'icons/obj/bath_mat.dmi'
	icon_state = "bath_mat"
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE

#undef BATH_SPILL_GAP
#undef BATH_DRIP_TIME
